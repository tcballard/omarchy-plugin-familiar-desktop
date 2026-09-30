#!/usr/bin/env python3
"""Familiar's local Hyprbars adapter. Dependency setup runs outside the shell.

The shell calls reconcile with literal argv; no downloading or building occurs
there. Only setup edits the user's config, using a marked, removable block.
"""
import argparse
import fcntl
import getpass
import json
import os
from pathlib import Path
import re
import selectors
import signal
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import stat

PLUGIN_ID = "io.github.tcballard.familiar-desktop"
REPOSITORY = "https://github.com/hyprwm/hyprland-plugins"
BEGIN = "-- BEGIN Familiar Desktop title bars"
END = "-- END Familiar Desktop title bars"
SOURCE = Path(__file__).resolve().parent.parent


class Failure(Exception):
    pass


def run(argv, timeout=8):
    # Bound stdout and stderr while receiving, with one whole-operation deadline.
    # These are local CLI calls, never dependency installers or shell pipelines.
    try:
        child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    except OSError as exc:
        raise Failure(str(exc)) from exc
    deadline = time.monotonic() + timeout
    buffers = {child.stdout: bytearray(), child.stderr: bytearray()}
    completed = False
    try:
        with selectors.DefaultSelector() as selector:
            for stream in buffers:
                selector.register(stream, selectors.EVENT_READ)
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise Failure("Command timed out")
                for key, _ in selector.select(remaining):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    if len(buffers[key.fileobj]) + len(chunk) > 1024 * 1024:
                        raise Failure("Command response exceeded 1 MiB")
                    buffers[key.fileobj].extend(chunk)
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise Failure("Command timed out")
            child.wait(timeout=remaining)
            completed = True
    except subprocess.TimeoutExpired as exc:
        raise Failure("Command timed out") from exc
    finally:
        if not completed:
            # Keep the original child unreaped until signalling its session.
            # This prevents PID reuse and also stops children holding a pipe.
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        child.wait()
        for stream in buffers:
            stream.close()
    text = buffers[child.stdout].decode("utf-8", errors="replace")
    if child.returncode:
        text = buffers[child.stderr].decode("utf-8", errors="replace") or text
        raise Failure(text.strip()[:300] or "Command failed")
    return text


def hypr(*args):
    return run(["hyprctl", *args])


def checked(*args):
    result = hypr(*args)
    if result.strip().lower() != "ok":
        raise Failure(result.strip()[:300] or "Hyprland did not acknowledge the command")


def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temp = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def read_json(path):
    try:
        # The active theme is a symlink by design. Validate the opened object,
        # avoiding a stat/read race and rejecting FIFOs/devices before reading.
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        with os.fdopen(fd, "rb") as stream:
            if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                raise Failure("Settings must be a regular file")
            content = stream.read(256 * 1024 + 1)
        if len(content) > 256 * 1024:
            raise Failure("Settings file exceeds 256 KiB")
        value = json.loads(content)
    except FileNotFoundError:
        return {}
    except (ValueError, OSError) as exc:
        raise Failure("Could not read title-bar settings") from exc
    if not isinstance(value, dict):
        raise Failure("Expected settings object")
    return value


def lua(value):
    # JSON escapes overlap Lua for ordinary text, but JSON's \u escape does not.
    text = str(value)
    return '"' + ''.join(('\\%03d' % ord(c)) if ord(c) < 32 else
                        ('\\' + c if c in '\\"' else c) for c in text) + '"'


def rgb(value):
    value = str(value)
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        raise Failure("Expected a six-digit theme colour")
    return "rgb(" + value[1:] + ")"


def theme_policy(args):
    path = Path.home() / ".local/state/omarchy/current/theme/familiar-desktop.json"
    document = read_json(path)
    version = document.get("schemaVersion", 1)
    if type(version) is not int or version != 1:
        raise Failure("Unsupported familiar-desktop.json schemaVersion")
    theme = document.get("titlebars", {})
    if not isinstance(theme, dict):
        raise Failure("Theme titlebars must be an object")
    mode = args.mode or args.style
    options = dict(enabled=False, style="windows", height=34, fontSize=args.font_size,
                   fontFamily=args.font_family, textAlign="center", buttonSize=18,
                   edgePadding=10, buttonPadding=9, background=args.background,
                   foreground=args.foreground, buttonForeground="#ffffff",
                   closeColour="#ff605c", minimizeColour=None, maximizeColour=None,
                   exclusions=[])
    unknown = set(theme) - set(options)
    if unknown:
        raise Failure("Unknown title-bar theme keys: " + ", ".join(sorted(unknown)))
    options.update(theme)
    if options["style"] not in ("mac", "windows") or type(options["enabled"]) is not bool:
        raise Failure("Theme requires boolean enabled and mac/windows style")
    if mode in ("mac", "windows"):
        options.update(enabled=True, style=mode)
    elif mode == "off":
        options["enabled"] = False
    elif mode != "theme":
        raise Failure("Unknown window-control mode")
    bounds = dict(height=(24, 80), fontSize=(8, 32), buttonSize=(12, 36),
                  edgePadding=(0, 40), buttonPadding=(2, 30))
    for key, (minimum, maximum) in bounds.items():
        value = options[key]
        if type(value) is not int or not minimum <= value <= maximum:
            raise Failure("Theme " + key + " is outside its supported range")
    if options["buttonSize"] > options["height"] - 4 or options["fontSize"] > options["height"] - 4:
        raise Failure("Theme height must leave room for its buttons and text")
    if options["textAlign"] not in ("left", "center"):
        raise Failure("Theme textAlign must be left or center")
    font = options["fontFamily"]
    if not isinstance(font, str) or not font or len(font) > 200 or any(ord(c) < 32 for c in font):
        raise Failure("Theme fontFamily must be a plain font name")
    mac = options["style"] == "mac"
    for key, fallback in (("minimizeColour", "#ffbd44" if mac else "#646d7e"),
                          ("maximizeColour", "#00ca4e" if mac else "#646d7e")):
        if options[key] is None:
            options[key] = fallback
    for key in ("background", "foreground", "buttonForeground", "closeColour", "minimizeColour", "maximizeColour"):
        rgb(options[key])
    exclusions = options["exclusions"]
    if not isinstance(exclusions, list) or any(not isinstance(c, str) for c in exclusions):
        raise Failure("Theme exclusions must be a list of window classes")
    exclusions = list(dict.fromkeys(exclusions + [c.strip() for c in args.exclude.split(",") if c.strip()]))
    if len(exclusions) > 32 or any(not c or len(c) > 200 or any(ord(x) < 32 for x in c) for c in exclusions):
        raise Failure("Use up to 32 app classes, each under 200 characters")
    options["exclusions"] = exclusions
    return options


def render(library, style, background, foreground, exclusions, options=None):
    if style not in ("mac", "windows"):
        raise Failure("Unknown title-bar style")
    # Hyprbars traverses the button list from its selected edge inward.
    options = options or dict(height=34, fontSize=13, fontFamily="Sans", textAlign="center",
                              buttonSize=18, edgePadding=10, buttonPadding=9,
                              buttonForeground="#ffffff", closeColour="#ff605c",
                              minimizeColour="#ffbd44" if style == "mac" else "#646d7e",
                              maximizeColour="#00ca4e" if style == "mac" else "#646d7e")
    buttons = [("close", options["closeColour"], "×"),
               ("minimize", options["minimizeColour"], "−"),
               ("maximize", options["maximizeColour"], "+" if style == "mac" else "□")]
    if style == "windows":
        buttons[1], buttons[2] = buttons[2], buttons[1]
    def action(name):
        return shlex.join([sys.executable, str(SOURCE / "scripts/familiar-titlebars.py"), "action", name])
    lines = ["-- Generated by Familiar Desktop; configure it from Familiar's settings.",
             "local manifest = io.open(" + lua(SOURCE / "manifest.json") + ", 'r')",
             "if not manifest then return end", "manifest:close()",
             "local library = io.open(" + lua(library) + ", 'r')",
             "if not library then return end", "library:close()",
             "hl.plugin.load(" + lua(library) + ")",
             "if not hl.plugin.hyprbars then return end",
             "hl.config({ plugin = { hyprbars = {",
             "  enabled = true, bar_height = " + str(options["height"]) + ", bar_text_size = " + str(options["fontSize"]) + ",",
             "  bar_title_enabled = true, bar_text_font = " + lua(options["fontFamily"]) + ", bar_text_align = " + lua(options["textAlign"]) + ",",
             "  bar_color = " + lua(rgb(background)) + ", ['col.text'] = " + lua(rgb(foreground)) + ",",
             "  bar_buttons_alignment = " + lua("left" if style == "mac" else "right") + ",",
             "  bar_padding = " + str(options["edgePadding"]) + ", bar_button_padding = " + str(options["buttonPadding"]) + ", bar_part_of_window = true,",
             "  buttons_on_hover = false, icon_on_hover = false,",
             "  on_double_click = " + lua(action("maximize")),
             "} } })"]
    for name, colour, icon in buttons:
        lines.append("hl.plugin.hyprbars.add_button({ bg_color = " + lua(rgb(colour)) +
                     ", fg_color = " + lua(rgb(options["buttonForeground"])) + ", size = " + str(options["buttonSize"]) + ", icon = " + lua(icon) +
                     ", action = " + lua(action(name)) + " })")
    # Exact class matches, with regex metacharacters escaped, never arbitrary Lua.
    for i, cls in enumerate(exclusions):
        pattern = "^(" + re.escape(cls) + ")$"
        lines.append("hl.window_rule({ name = 'familiar-titlebars-exclude-" + str(i) +
                     "', match = { class = " + lua(pattern) + " }, ['hyprbars:no_bar'] = true })")
    return "\n".join(lines) + "\n"


def paths():
    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    directory = config / "omarchy/familiar-titlebars"
    return directory, config / "hypr/looknfeel.lua"


def hook_text(generated):
    return (BEGIN + "\nlocal familiarFile = io.open(" + lua(generated) + ", 'r')\n"
            "if familiarFile then\n  familiarFile:close()\n  dofile(" + lua(generated) + ")\nend\n" + END + "\n")


def strip_hook(text):
    if text.count(BEGIN) != text.count(END) or text.count(BEGIN) > 1:
        raise Failure("Familiar's configuration markers are damaged; no file was changed")
    return re.sub(re.escape(BEGIN) + r"\n.*?" + re.escape(END) + r"\n?", "", text, flags=re.S)


def loaded():
    try:
        plugins = json.loads(hypr("-j", "plugin", "list"))
    except ValueError as exc:
        raise Failure("Hyprland returned an invalid plugin list") from exc
    if not isinstance(plugins, list) or any(not isinstance(p, dict) for p in plugins):
        raise Failure("Hyprland returned an invalid plugin list")
    return any(p.get("name") == "hyprbars" for p in plugins)


def find_library():
    roots = [Path("/var/cache/hyprpm") / getpass.getuser(),
             Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "hyprpm"]
    candidates = [p for root in roots for p in root.glob("*/hyprbars.so") if p.is_file()]
    if len(candidates) != 1:
        raise Failure("Install Hyprbars using hyprpm first, then run setup again")
    return candidates[0].resolve()


def setup(args, directory, config):
    state_file = directory / "owner.json"
    state = read_json(state_file)
    if loaded() and not state:
        raise Failure("Hyprbars is already in use. Disable your existing setup before using Familiar title bars")
    if not config.is_file():
        raise Failure("This integration requires Omarchy's Lua config at ~/.config/hypr/looknfeel.lua")
    original = config.read_text()
    clean = strip_hook(original)
    settings_path = Path.home() / ".config/omarchy/familiar-desktop-settings.json"
    settings = read_json(settings_path) if args.enable else {}
    if args.install_dependency:
        # An explicit, interactive terminal operation, never called from QML.
        if subprocess.run(["hyprpm", "update"]).returncode:
            raise Failure("Hyprbars update failed; no config hook was added")
        try:
            find_library()
        except Failure:
            if subprocess.run(["hyprpm", "add", REPOSITORY]).returncode:
                raise Failure("Hyprbars installation failed; no config hook was added")
    library = Path(args.library).expanduser().resolve() if args.library else find_library()
    if not library.is_file() or library.name != "hyprbars.so":
        raise Failure("Expected an installed hyprbars.so")
    # Probe compatibility without replacing an existing user's configuration.
    if not loaded():
        checked("plugin", "load", str(library))
        try:
            checked("eval", "assert(hl.plugin.hyprbars and hl.plugin.hyprbars.add_button, 'Familiar requires Hyprbars with Lua button support')")
        finally:
            checked("plugin", "unload", str(library))
    generated = directory / "titlebars.lua"
    if not state_file.exists():
        atomic(generated, "-- Familiar title bars are disabled.\n")
    atomic(state_file, json.dumps({"library": str(library), "source": str(SOURCE), "config": str(config)}) + "\n")
    atomic(config, clean.rstrip() + "\n\n" + hook_text(generated))
    if args.enable:
        settings.update(titlebarsEnabled=True, titlebarStyle=args.style, titlebarMode=args.style, dockEnabled=True)
        atomic(settings_path, json.dumps(settings, indent=2) + "\n")
    return {"state": "ready", "message": "Setup complete. Enable Window controls in Familiar Desktop."}


def reconcile(args, directory, config):
    state = read_json(directory / "owner.json")
    if not state:
        return {"state": "setup-required", "message": "One-time title-bar setup is needed."}
    if state.get("source") != str(SOURCE):
        raise Failure("Title bars belong to another Familiar installation; run setup from the installed plugin")
    if BEGIN not in config.read_text():
        return {"state": "setup-required", "message": "The title-bar configuration hook is missing."}
    if args.operation == "disable" and args.if_owner and state.get("session") != args.owner:
        return {"state": "off", "message": "A newer Familiar instance owns the controls."}
    current = str(state.get("session", "")).split("-", 1)[0]
    incoming = args.owner.split("-", 1)[0]
    if current.isdigit() and incoming.isdigit() and int(incoming) < int(current):
        return {"state": "off", "message": "A newer Familiar instance owns the controls."}
    if args.operation == "disable":
        content = "-- Familiar title bars are disabled.\n"
    else:
        library = Path(state["library"])
        if not library.is_file():
            return {"state": "missing", "message": "Hyprbars is missing. Run title-bar setup again."}
        try:
            policy = theme_policy(args)
        except Failure:
            atomic(directory / "titlebars.lua", "-- Title bars disabled after a theme validation error.\n")
            checked("reload")
            raise
        if policy["enabled"]:
            content = render(library, policy["style"], policy["background"], policy["foreground"], policy["exclusions"], policy)
        else:
            content = "-- Familiar title bars are disabled by the active theme.\n"
    state["session"] = args.owner
    atomic(directory / "owner.json", json.dumps(state) + "\n")
    generated = directory / "titlebars.lua"
    if not generated.exists() or generated.read_text() != content:
        atomic(generated, content)
        try:
            checked("reload")
        except Failure:
            atomic(generated, "-- Title bars disabled after a reload failure.\n")
            raise
    active = args.operation != "disable" and policy["enabled"]
    if active:
        try:
            if not loaded():
                raise Failure("Hyprbars did not load; check compatibility with your Hyprland build")
            checked("eval", "assert(hl.plugin.hyprbars and hl.plugin.hyprbars.add_button, 'Hyprbars Lua button support is missing')")
            errors = hypr("configerrors").strip()
            if errors:
                raise Failure(errors[:300])
        except Failure:
            # Fail closed: no broken generated config left on disk.
            atomic(generated, "-- Title bars disabled after a configuration error.\n")
            checked("reload")
            raise
    return {"state": "active" if active else "off",
            "message": "Window controls follow the active theme." if active and args.mode == "theme" else
                       "Window controls are active." if active else "Window controls are off."}


def window_action(name):
    try:
        client = json.loads(hypr("-j", "activewindow"))
    except ValueError as exc:
        raise Failure("Hyprland returned invalid window information") from exc
    if not isinstance(client, dict):
        raise Failure("Hyprland returned invalid window information")
    address = str(client.get("address", ""))
    if not re.fullmatch(r"0x[0-9a-fA-F]+", address):
        raise Failure("No active window")
    if name == "minimize":
        run([sys.executable, str(SOURCE / "scripts/dock-minimize.py"), "minimize-instance", address])
    elif name == "close":
        checked("dispatch", "hl.dsp.window.close({ window = " + lua("address:" + address) + " })")
    else:
        checked("dispatch", "hl.dsp.window.fullscreen({ window = " + lua("address:" + address) +
                ", mode = 'maximized', action = 'toggle' })")
    return {"state": "ok"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["setup", "apply", "disable", "remove", "action"])
    parser.add_argument("action", nargs="?", choices=["close", "minimize", "maximize"])
    parser.add_argument("--install-dependency", action="store_true")
    parser.add_argument("--enable", action="store_true")
    parser.add_argument("--library")
    parser.add_argument("--owner", default="")
    parser.add_argument("--if-owner", action="store_true")
    parser.add_argument("--style", choices=["mac", "windows"], default="mac")
    parser.add_argument("--mode", choices=["theme", "off", "mac", "windows"])
    parser.add_argument("--font-family", default="Sans")
    parser.add_argument("--font-size", type=int, default=13)
    parser.add_argument("--background", default="#202020")
    parser.add_argument("--foreground", default="#ffffff")
    parser.add_argument("--exclude", default="")
    args = parser.parse_args()
    directory, config = paths()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        if not shutil.which("hyprctl"):
            raise Failure("Run this inside your Omarchy desktop")
        if args.operation == "action":
            if not args.action:
                raise Failure("Choose a window action")
            print(json.dumps(window_action(args.action)))
            return 0
        with (directory / "lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.operation == "setup":
                result = setup(args, directory, config)
            elif args.operation == "remove":
                state = read_json(directory / "owner.json")
                if state:
                    atomic(config, strip_hook(config.read_text()))
                    (directory / "titlebars.lua").unlink(missing_ok=True)
                    (directory / "owner.json").unlink(missing_ok=True)
                    checked("reload")
                result = {"state": "removed", "message": "Familiar's title-bar hook was removed."}
            else:
                result = reconcile(args, directory, config)
        print(json.dumps(result))
        return 0
    except (Failure, OSError, ValueError, KeyError) as exc:
        print(json.dumps({"state": "failed", "message": str(exc)[:300]}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
