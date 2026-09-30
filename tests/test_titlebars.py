"""Title-bar lifecycle and window-action regression tests with a fake compositor."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import sys
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("titlebars", Path(__file__).parents[1] / "scripts/familiar-titlebars.py")
tb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tb)


class TitlebarsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / "titlebars"
        self.directory.mkdir()
        self.config = Path(self.temp.name) / "looknfeel.lua"
        self.original = "-- personal overrides\nhl.config({ decoration = { rounding = 9 } })\n"
        self.config.write_text(self.original)
        self.library = Path(self.temp.name) / "hyprbars.so"
        self.library.touch()
        self.args = argparse.Namespace(operation="apply", owner="200-new", if_owner=False,
                                       style="mac", background="#202020", foreground="#ffffff",
                                       exclude="", library=str(self.library), install_dependency=False, enable=False,
                                       mode=None, font_family="Sans", font_size=13)
        home = patch.object(tb.Path, "home", return_value=Path(self.temp.name))
        home.start()
        self.addCleanup(home.stop)
        self.loaded = False
        self.errors = ""
        self.calls = []
        self.reloading_fails = False
        self.load_on_reload = True
        self.mock = patch.object(tb, "hypr", side_effect=self.hypr)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def hypr(self, *args):
        self.calls.append(args)
        if args == ("-j", "plugin", "list"):
            return json.dumps([{"name": "hyprbars"}] if self.loaded else [])
        if args[:2] == ("plugin", "load"):
            self.loaded = True
        if args[:2] == ("plugin", "unload"):
            self.loaded = False
        if args == ("reload",):
            if self.reloading_fails:
                return "error: reload rejected"
            content = (self.directory / "titlebars.lua").read_text()
            self.loaded = "hl.plugin.load" in content and self.load_on_reload
        if args == ("configerrors",):
            return self.errors
        return "ok"

    def setup(self):
        return tb.setup(self.args, self.directory, self.config)

    def reconcile(self):
        return tb.reconcile(self.args, self.directory, self.config)

    def test_missing_dependency_requires_setup_without_touching_personal_config(self):
        self.assertEqual(self.reconcile()["state"], "setup-required")
        self.assertEqual(self.config.read_text(), self.original)

    def test_setup_is_idempotent_and_removable_with_personal_overrides_preserved(self):
        self.setup()
        self.setup()
        text = self.config.read_text()
        self.assertEqual(text.count(tb.BEGIN), 1)
        self.assertEqual(tb.strip_hook(text).rstrip(), self.original.rstrip())
        self.assertFalse(self.loaded)

    def test_existing_hyprbars_is_not_adopted(self):
        self.loaded = True
        with self.assertRaisesRegex(tb.Failure, "already in use"):
            self.setup()
        self.assertFalse((self.directory / "owner.json").exists())
        self.assertEqual(self.config.read_text(), self.original)

    def test_enable_theme_update_disable_and_reload_are_idempotent(self):
        self.setup()
        self.assertEqual(self.reconcile()["state"], "active")
        self.calls.clear()
        self.reconcile()
        self.assertNotIn(("reload",), self.calls)
        self.args.background = "#123456"
        self.reconcile()
        self.assertIn("rgb(123456)", (self.directory / "titlebars.lua").read_text())
        self.args.operation = "disable"
        self.assertEqual(self.reconcile()["state"], "off")
        self.assertFalse(self.loaded)

    def test_old_teardown_and_late_apply_cannot_overwrite_new_instance(self):
        self.setup()
        self.reconcile()
        active = (self.directory / "titlebars.lua").read_text()
        self.args.owner = "100-old"
        self.args.operation = "disable"
        self.args.if_owner = True
        self.reconcile()
        self.assertEqual((self.directory / "titlebars.lua").read_text(), active)
        self.args.operation = "apply"
        self.args.if_owner = False
        self.args.style = "windows"
        self.reconcile()
        self.assertEqual((self.directory / "titlebars.lua").read_text(), active)

    def test_a_new_instance_can_disable_a_previous_sessions_controls(self):
        self.setup()
        self.reconcile()
        self.args.owner = "300-restart"
        self.args.operation = "disable"
        self.assertEqual(self.reconcile()["state"], "off")
        self.assertFalse(self.loaded)

    def test_configuration_error_fails_closed(self):
        self.setup()
        self.errors = "invalid window rule"
        with self.assertRaisesRegex(tb.Failure, "invalid window rule"):
            self.reconcile()
        self.assertNotIn("hl.plugin.load", (self.directory / "titlebars.lua").read_text())
        self.assertFalse(self.loaded)

    def test_binary_mismatch_does_not_leave_active_configuration(self):
        self.setup()
        self.load_on_reload = False
        with self.assertRaisesRegex(tb.Failure, "did not load"):
            self.reconcile()
        self.assertNotIn("hl.plugin.load", (self.directory / "titlebars.lua").read_text())

    def test_failed_reload_does_not_persist_active_configuration(self):
        self.setup()
        self.reloading_fails = True
        with self.assertRaises(tb.Failure):
            self.reconcile()
        self.assertNotIn("hl.plugin.load", (self.directory / "titlebars.lua").read_text())

    def test_broken_markers_are_never_rewritten(self):
        self.config.write_text(self.original + tb.BEGIN + "\n")
        with self.assertRaisesRegex(tb.Failure, "markers"):
            self.setup()
        self.assertEqual(self.config.read_text(), self.original + tb.BEGIN + "\n")

    def test_theme_input_cannot_inject_lua(self):
        with self.assertRaises(tb.Failure):
            tb.render(self.library, "mac", '#ffffff); os.execute("bad")', "#ffffff", [])
        text = tb.render(Path("a ' quoted path/hyprbars.so"), "mac", "#123456", "#ffffff", ['org.app+name', 'a"; os.execute("bad")'])
        self.assertIn('class = "^(org\\\\.app\\\\+name)$"', text)
        self.assertIn('a\\";', text)

    def test_styles_change_order_and_alignment(self):
        mac = tb.render(self.library, "mac", "#202020", "#ffffff", [])
        win = tb.render(self.library, "windows", "#202020", "#ffffff", [])
        self.assertIn('bar_buttons_alignment = "left"', mac)
        self.assertIn('bar_buttons_alignment = "right"', win)
        # Compare rendered argv actions rather than text labels.
        self.assertLess(mac.index('action minimize'), mac.index('action maximize', mac.index('add_button')))
        self.assertLess(win.index('action maximize', win.index('add_button')), win.index('action minimize'))

    def test_minimise_reuses_dock_helper_with_an_explicit_address(self):
        with patch.object(tb, "hypr", return_value='{"address":"0xABC"}'), patch.object(tb, "run") as run:
            tb.window_action("minimize")
            self.assertEqual(run.call_args.args[0][-2:], ["minimize-instance", "0xABC"])

    def test_close_and_maximise_do_not_use_an_unqualified_active_dispatch(self):
        for action in ("close", "maximize"):
            with patch.object(tb, "hypr", return_value='{"address":"0xABC"}'), patch.object(tb, "checked") as checked:
                tb.window_action(action)
                self.assertIn('address:0xABC', checked.call_args.args[1])

    def test_invalid_address_cannot_become_a_command(self):
        with patch.object(tb, "hypr", return_value='{"address":"0xA; bad"}'), patch.object(tb, "run") as run:
            with self.assertRaises(tb.Failure):
                tb.window_action("minimize")
            run.assert_not_called()

    def write_theme(self, options):
        path = Path(self.temp.name) / ".local/state/omarchy/current/theme/familiar-desktop.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"schemaVersion": 1, "titlebars": options}))
        return path

    def test_theme_switch_changes_enablement_and_styling(self):
        self.setup()
        self.args.mode = "theme"
        self.assertEqual(self.reconcile()["state"], "off")
        self.write_theme(dict(enabled=True, style="windows", height=40, fontSize=16,
                              fontFamily="Inter", background="#fafafa", foreground="#121212",
                              closeColour="#b42318", minimizeColour="#62666c", maximizeColour="#0067b8",
                              buttonSize=20, buttonPadding=12, edgePadding=14, textAlign="left"))
        self.assertEqual(self.reconcile()["state"], "active")
        text = (self.directory / "titlebars.lua").read_text()
        for fragment in ['bar_height = 40', 'bar_text_size = 16', 'bar_text_font = "Inter"',
                         'bar_buttons_alignment = "right"', 'rgb(fafafa)', 'rgb(b42318)',
                         'size = 20', 'bar_button_padding = 12', 'bar_padding = 14']:
            self.assertIn(fragment, text)
        self.write_theme(dict(enabled=False, style="mac"))
        self.assertEqual(self.reconcile()["state"], "off")
        self.assertFalse(self.loaded)

    def test_manual_style_overrides_theme_layout_and_enablement(self):
        self.write_theme(dict(enabled=False, style="windows", height=42))
        self.args.mode = "mac"
        policy = tb.theme_policy(self.args)
        self.assertTrue(policy["enabled"])
        self.assertEqual(policy["style"], "mac")
        self.assertEqual(policy["height"], 42)
        self.assertEqual(policy["minimizeColour"], "#ffbd44")

    def test_shared_shell_font_and_palette_are_fallbacks(self):
        self.args.font_family = "Theme Sans"
        self.args.font_size = 15
        self.args.background = "#eeeeee"
        policy = tb.theme_policy(self.args)
        self.assertEqual(policy["fontFamily"], "Theme Sans")
        self.assertEqual(policy["fontSize"], 15)
        self.assertEqual(policy["background"], "#eeeeee")

    def test_theme_and_user_exclusions_merge_without_duplicates(self):
        self.write_theme(dict(exclusions=["kitty", "org.gnome.Nautilus"]))
        self.args.exclude = "kitty,firefox"
        self.assertEqual(tb.theme_policy(self.args)["exclusions"], ["kitty", "org.gnome.Nautilus", "firefox"])

    def test_invalid_theme_fails_closed_and_can_be_disabled(self):
        self.setup()
        self.reconcile()
        self.write_theme(dict(enabled=True, height=5))
        with self.assertRaisesRegex(tb.Failure, "height"):
            self.reconcile()
        self.assertFalse(self.loaded)
        self.args.operation = "disable"
        self.assertEqual(self.reconcile()["state"], "off")

    def test_invalid_theme_values_cannot_inject_lua_or_clip_controls(self):
        cases = [dict(enabled="true"), dict(style="bad"), dict(height=True), dict(buttonSize=36, height=24),
                 dict(background="red"), dict(fontFamily="Sans\nwrong"), dict(exclusions="kitty"),
                 dict(buttonPadding=1000), dict(unknown="value")]
        for options in cases:
            with self.subTest(options=options):
                self.write_theme(options)
                with self.assertRaises(tb.Failure):
                    tb.theme_policy(self.args)


class AdapterLimitsTest(unittest.TestCase):
    def test_stdout_and_stderr_overflow_are_stopped_while_receiving(self):
        for descriptor in (1, 2):
            with self.subTest(descriptor=descriptor):
                started = time.monotonic()
                with self.assertRaisesRegex(tb.Failure, "exceeded"):
                    tb.run([sys.executable, "-c", f"import os;\nwhile True: os.write({descriptor}, b'x'*65536)"], timeout=3)
                self.assertLess(time.monotonic() - started, 3)

    def test_stalled_descendant_is_terminated_with_original_child(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "descendant-survived"
            code = "import os,time,pathlib;\nif os.fork() == 0:\n time.sleep(0.5); pathlib.Path(" + repr(str(marker)) + ").touch()\nelse:\n time.sleep(5)"
            with self.assertRaisesRegex(tb.Failure, "timed out"):
                tb.run([sys.executable, "-c", code], timeout=0.1)
            time.sleep(0.6)
            self.assertFalse(marker.exists())

    def test_nonzero_stderr_is_bounded_and_reported(self):
        with self.assertRaises(tb.Failure) as error:
            tb.run([sys.executable, "-c", "import sys; sys.stderr.write('e'*1000); sys.exit(1)"])
        self.assertEqual(len(str(error.exception)), 300)
        self.assertEqual(tb.run([sys.executable, "-c", "print('ok')"]), "ok\n")

    def test_settings_reads_are_bounded_and_reject_nonregular_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            self.assertEqual(tb.read_json(path), {})
            path.write_bytes(b' ' * (256 * 1024 + 1))
            with self.assertRaisesRegex(tb.Failure, "exceeds"):
                tb.read_json(path)
            path.unlink()
            os.mkfifo(path)
            with self.assertRaisesRegex(tb.Failure, "regular file"):
                tb.read_json(path)
            path.unlink()
            target = Path(directory) / "theme.json"
            target.write_text('{"schemaVersion":1}')
            path.symlink_to(target)
            self.assertEqual(tb.read_json(path), {"schemaVersion": 1})


if __name__ == "__main__":
    unittest.main()
