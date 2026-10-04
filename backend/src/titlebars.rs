use crate::{
    Result,
    common::{self, Hypr, atomic, checked, lua, read_json, shell_quote},
};
use serde_json::{Value, json};
use std::{
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

pub const BEGIN: &str = "-- BEGIN Familiar Desktop title bars";
pub const END: &str = "-- END Familiar Desktop title bars";
pub const REPOSITORY: &str = "https://github.com/hyprwm/hyprland-plugins";
#[derive(Clone, Debug)]
pub struct Args {
    pub operation: String,
    pub action: String,
    pub owner: String,
    pub if_owner: bool,
    pub style: String,
    pub mode: String,
    pub background: String,
    pub foreground: String,
    pub font_family: String,
    pub font_size: i64,
    pub size: String,
    pub exclude: String,
    pub library: Option<PathBuf>,
    pub install_dependency: bool,
    pub enable: bool,
}
impl Default for Args {
    fn default() -> Self {
        Self {
            operation: "apply".into(),
            action: String::new(),
            owner: String::new(),
            if_owner: false,
            style: "mac".into(),
            mode: String::new(),
            background: "#202020".into(),
            foreground: "#ffffff".into(),
            font_family: "Sans".into(),
            font_size: 13,
            size: "default".into(),
            exclude: String::new(),
            library: None,
            install_dependency: false,
            enable: false,
        }
    }
}
impl Args {
    pub fn parse(argv: &[String]) -> Result<Self> {
        let mut a = Self {
            operation: argv.first().ok_or("Choose a title-bar operation")?.clone(),
            ..Self::default()
        };
        if !["setup", "apply", "disable", "remove", "action"].contains(&a.operation.as_str()) {
            return Err("Unknown title-bar operation".into());
        }
        let mut i = 1;
        if a.operation == "action" {
            a.action = argv.get(i).ok_or("Choose a window action")?.clone();
            i += 1;
        }
        while i < argv.len() {
            let key = &argv[i];
            i += 1;
            match key.as_str() {
                "--if-owner" => a.if_owner = true,
                "--enable" => a.enable = true,
                "--install-dependency" => a.install_dependency = true,
                "--owner" | "--style" | "--mode" | "--background" | "--foreground"
                | "--size" | "--font-family" | "--font-size" | "--exclude" | "--library" => {
                    let value = argv
                        .get(i)
                        .ok_or_else(|| format!("Missing value for {key}"))?
                        .clone();
                    i += 1;
                    match key.as_str() {
                        "--owner" => a.owner = value,
                        "--style" => a.style = value,
                        "--mode" => a.mode = value,
                        "--background" => a.background = value,
                        "--foreground" => a.foreground = value,
                        "--font-family" => a.font_family = value,
                        "--size" => a.size = value,
                        "--font-size" => {
                            a.font_size = value.parse().map_err(|_| "Invalid font size")?
                        }
                        "--exclude" => a.exclude = value,
                        "--library" => a.library = Some(PathBuf::from(value)),
                        _ => unreachable!(),
                    }
                }
                _ => return Err(format!("Unknown title-bar option {key}")),
            }
        }
        if !["mac", "windows"].contains(&a.style.as_str())
            || !["", "theme", "off", "mac", "windows"].contains(&a.mode.as_str())
        {
            return Err("Unknown window-control style/mode".into());
        }
        Ok(a)
    }
}
#[derive(Clone)]
pub struct Paths {
    pub home: PathBuf,
    pub source: PathBuf,
    pub binary: PathBuf,
    pub directory: PathBuf,
    pub config: PathBuf,
}
impl Paths {
    pub fn system() -> Result<Self> {
        let home = common::home()?;
        let binary = env::current_exe().map_err(|e| e.to_string())?;
        let source = binary
            .parent()
            .and_then(Path::parent)
            .ok_or("Install the helper in the plugin bin directory")?
            .to_path_buf();
        let config = common::config_home()?;
        Ok(Self {
            home,
            source,
            binary,
            directory: config.join("omarchy/familiar-titlebars"),
            config: config.join("hypr/looknfeel.lua"),
        })
    }
}
pub fn rgb(value: &str) -> Result<String> {
    if value.len() != 7
        || !value.starts_with('#')
        || !value[1..].bytes().all(|b| b.is_ascii_hexdigit())
    {
        return Err("Expected a six-digit theme colour".into());
    }
    Ok(format!("rgb({})", &value[1..]))
}
fn plain(s: &str) -> bool {
    !s.is_empty() && s.chars().count() <= 200 && !s.chars().any(char::is_control)
}
pub fn theme_policy(document: &Value, args: &Args) -> Result<Value> {
    if document.get("schemaVersion").unwrap_or(&json!(1)).as_u64() != Some(1) {
        return Err("Unsupported familiar-desktop.json schemaVersion".into());
    }
    let theme = document.get("titlebars").cloned().unwrap_or(json!({}));
    let theme = theme
        .as_object()
        .ok_or("Theme titlebars must be an object")?;
    let mut options = json!({"enabled":false,"style":"windows","height":34,"fontSize":args.font_size,"fontFamily":args.font_family,"textAlign":"center","buttonSize":18,"edgePadding":10,"buttonPadding":9,"background":args.background,"foreground":args.foreground,"buttonForeground":"#ffffff","closeColour":"#ff605c","minimizeColour":null,"maximizeColour":null,"exclusions":[]});
    for (key, value) in theme {
        if options.get(key).is_none() {
            return Err(format!("Unknown title-bar theme key: {key}"));
        }
        options[key] = value.clone();
    }
    if options["enabled"].as_bool().is_none()
        || !matches!(options["style"].as_str(), Some("mac" | "windows"))
    {
        return Err("Theme requires boolean enabled and mac/windows style".into());
    }
    let mode = if args.mode.is_empty() {
        &args.style
    } else {
        &args.mode
    };
    match mode.as_str() {
        "mac" | "windows" => {
            options["enabled"] = json!(true);
            options["style"] = json!(mode);
        }
        "off" => options["enabled"] = json!(false),
        "theme" => {}
        _ => return Err("Unknown window-control mode".into()),
    }
    match args.size.as_str() {
        "default" => {},
        "large" => { options["height"] = json!(44); options["buttonSize"] = json!(26); options["fontSize"] = json!(15); },
        "extra-large" => { options["height"] = json!(52); options["buttonSize"] = json!(32); options["fontSize"] = json!(17); },
        _ => return Err("Unknown title-bar size".into()),
    }
    for (key, min, max) in [
        ("height", 24, 80),
        ("fontSize", 8, 32),
        ("buttonSize", 12, 36),
        ("edgePadding", 0, 40),
        ("buttonPadding", 2, 30),
    ] {
        let n = options[key]
            .as_i64()
            .ok_or_else(|| format!("Theme {key} must be an integer"))?;
        if n < min || n > max {
            return Err(format!("Theme {key} is outside its supported range"));
        }
    }
    if options["buttonSize"].as_i64().unwrap() > options["height"].as_i64().unwrap() - 4
        || options["fontSize"].as_i64().unwrap() > options["height"].as_i64().unwrap() - 4
    {
        return Err("Theme height must leave room for its buttons and text".into());
    }
    if !matches!(options["textAlign"].as_str(), Some("left" | "center")) {
        return Err("Theme textAlign must be left or center".into());
    }
    if !options["fontFamily"].as_str().is_some_and(plain) {
        return Err("Theme fontFamily must be a plain font name".into());
    }
    let mac = options["style"] == "mac";
    for (key, fallback) in [
        ("minimizeColour", if mac { "#ffbd44" } else { "#646d7e" }),
        ("maximizeColour", if mac { "#00ca4e" } else { "#646d7e" }),
    ] {
        if options[key].is_null() {
            options[key] = json!(fallback);
        }
    }
    for key in [
        "background",
        "foreground",
        "buttonForeground",
        "closeColour",
        "minimizeColour",
        "maximizeColour",
    ] {
        rgb(options[key]
            .as_str()
            .ok_or("Expected theme colour string")?)?;
    }
    let mut exclusions = Vec::<String>::new();
    for value in options["exclusions"]
        .as_array()
        .ok_or("Theme exclusions must be a list of window classes")?
    {
        let s = value.as_str().ok_or("Exclusions must be strings")?;
        if !plain(s) {
            return Err("Invalid excluded window class".into());
        }
        if !exclusions.iter().any(|x| x == s) {
            exclusions.push(s.into());
        }
    }
    for s in args
        .exclude
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        if !plain(s) {
            return Err("Invalid excluded window class".into());
        }
        if !exclusions.iter().any(|x| x == s) {
            exclusions.push(s.into());
        }
    }
    if exclusions.len() > 32 {
        return Err("Use up to 32 excluded window classes".into());
    }
    options["exclusions"] = json!(exclusions);
    Ok(options)
}
pub fn render(paths: &Paths, library: &Path, o: &Value) -> Result<String> {
    let action =
        |name: &str| shell_quote(&paths.binary.to_string_lossy()) + " titlebars action " + name;
    let mut s = format!(
        "-- Generated by Familiar Desktop; configure it from Familiar's settings.\nlocal manifest = io.open({}, 'r')\nif not manifest then return end\nmanifest:close()\nlocal library = io.open({}, 'r')\nif not library then return end\nlibrary:close()\nhl.plugin.load({})\nif not hl.plugin.hyprbars then return end\nhl.config({{ plugin = {{ hyprbars = {{\n",
        lua(&paths.source.join("manifest.json").to_string_lossy()),
        lua(&library.to_string_lossy()),
        lua(&library.to_string_lossy())
    );
    s += &format!(
        "  enabled = true, bar_height = {}, bar_text_size = {},\n  bar_title_enabled = true, bar_text_font = {}, bar_text_align = {},\n  bar_color = {}, ['col.text'] = {},\n  bar_buttons_alignment = {},\n  bar_padding = {}, bar_button_padding = {}, bar_part_of_window = true,\n  buttons_on_hover = false, icon_on_hover = false,\n  on_double_click = {},\n}} }} }})\n",
        o["height"],
        o["fontSize"],
        lua(o["fontFamily"].as_str().ok_or("Missing font")?),
        lua(o["textAlign"].as_str().ok_or("Missing alignment")?),
        lua(&rgb(o["background"]
            .as_str()
            .ok_or("Missing background")?)?),
        lua(&rgb(o["foreground"]
            .as_str()
            .ok_or("Missing foreground")?)?),
        lua(if o["style"] == "mac" { "left" } else { "right" }),
        o["edgePadding"],
        o["buttonPadding"],
        lua(&action("maximize"))
    );
    let mut buttons = vec![
        ("close", "closeColour", "×"),
        ("minimize", "minimizeColour", "−"),
        (
            "maximize",
            "maximizeColour",
            if o["style"] == "mac" { "+" } else { "□" },
        ),
    ];
    if o["style"] == "windows" {
        buttons.swap(1, 2);
    }
    for (name, key, icon) in buttons {
        s += &format!(
            "hl.plugin.hyprbars.add_button({{ bg_color = {}, fg_color = {}, size = {}, icon = {}, action = {} }})\n",
            lua(&rgb(o[key].as_str().ok_or("Missing button colour")?)?),
            lua(&rgb(o["buttonForeground"]
                .as_str()
                .ok_or("Missing foreground")?)?),
            o["buttonSize"],
            lua(icon),
            lua(&action(name))
        );
    }
    for (i, cls) in o["exclusions"]
        .as_array()
        .ok_or("Missing exclusions")?
        .iter()
        .enumerate()
    {
        s += &format!(
            "hl.window_rule({{ name = 'familiar-titlebars-exclude-{i}', match = {{ class = {} }}, ['hyprbars:no_bar'] = true }})\n",
            lua(&format!(
                "^({})$",
                regex::escape(cls.as_str().ok_or("Invalid class")?)
            ))
        );
    }
    Ok(s)
}
pub fn strip_hook(text: &str) -> Result<String> {
    if text.matches(BEGIN).count() != text.matches(END).count() || text.matches(BEGIN).count() > 1 {
        return Err("Familiar's configuration markers are damaged; no file was changed".into());
    }
    if let Some(start) = text.find(BEGIN) {
        let end = text.find(END).ok_or("Damaged markers")? + END.len();
        if end < start {
            return Err("Damaged markers".into());
        }
        let end = if text[end..].starts_with('\n') {
            end + 1
        } else {
            end
        };
        Ok(format!("{}{}", &text[..start], &text[end..]))
    } else {
        Ok(text.into())
    }
}
fn text_file(path: &Path) -> Result<String> {
    String::from_utf8(common::bounded_file(path, common::FILE_LIMIT)?).map_err(|e| e.to_string())
}
fn loaded(hypr: &mut impl Hypr) -> Result<bool> {
    let v: Value = serde_json::from_str(&hypr.command(&["-j", "plugin", "list"])?)
        .map_err(|_| "Hyprland returned an invalid plugin list")?;
    let list = v
        .as_array()
        .ok_or("Hyprland returned an invalid plugin list")?;
    if list.iter().any(|v| !v.is_object()) {
        return Err("Hyprland returned an invalid plugin list".into());
    }
    Ok(list.iter().any(|v| v["name"] == "hyprbars"))
}
fn find_library(paths: &Paths) -> Result<PathBuf> {
    // Resolve username using the actual UID rather than trusting a USER variable.
    let username = fs::read_to_string("/etc/passwd")
        .unwrap_or_default()
        .lines()
        .find_map(|line| {
            let p: Vec<_> = line.split(':').collect();
            if p.len() > 2 && p[2].parse::<u32>().ok() == Some(unsafe { libc::getuid() }) {
                Some(p[0].to_string())
            } else {
                None
            }
        })
        .ok_or("Could not resolve local username")?;
    let roots = [
        PathBuf::from("/var/cache/hyprpm").join(username),
        env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .unwrap_or(paths.home.join(".local/share"))
            .join("hyprpm"),
    ];
    let mut candidates = Vec::new();
    for root in roots {
        if let Ok(entries) = fs::read_dir(root) {
            for e in entries.flatten() {
                let p = e.path().join("hyprbars.so");
                if p.is_file() {
                    let p = fs::canonicalize(p).map_err(|e| e.to_string())?;
                    if !candidates.contains(&p) {
                        candidates.push(p);
                    }
                }
            }
        }
    }
    if candidates.len() != 1 {
        return Err("Install Hyprbars using hyprpm first, then run setup again".into());
    }
    Ok(candidates.remove(0))
}
pub fn setup(args: &Args, paths: &Paths, hypr: &mut impl Hypr) -> Result<Value> {
    let state_file = paths.directory.join("owner.json");
    let state = read_json(&state_file)?;
    if loaded(hypr)? && state.as_object().is_some_and(|o| o.is_empty()) {
        return Err("Hyprbars is already in use. Disable your existing setup before using Familiar title bars".into());
    }
    if let Some(source) = state["source"].as_str()
        && source != paths.source.to_string_lossy()
    {
        return Err("Title bars belong to another Familiar installation".into());
    }
    let clean = strip_hook(&text_file(&paths.config)?)?;
    let settings_path = paths
        .home
        .join(".config/omarchy/familiar-desktop-settings.json");
    let mut settings = if args.enable {
        read_json(&settings_path)?
    } else {
        json!({})
    };
    if args.install_dependency {
        if !Command::new("hyprpm")
            .arg("update")
            .status()
            .map_err(|e| e.to_string())?
            .success()
        {
            return Err("Hyprbars update failed; no config hook was added".into());
        }
        if find_library(paths).is_err()
            && !Command::new("hyprpm")
                .args(["add", REPOSITORY])
                .status()
                .map_err(|e| e.to_string())?
                .success()
        {
            return Err("Hyprbars installation failed; no config hook was added".into());
        }
    }
    let library = if let Some(p) = &args.library {
        fs::canonicalize(p).map_err(|e| e.to_string())?
    } else {
        find_library(paths)?
    };
    if !library.is_file() || library.file_name().is_none_or(|n| n != "hyprbars.so") {
        return Err("Expected an installed hyprbars.so".into());
    }
    if !loaded(hypr)? {
        checked(hypr, &["plugin", "load", &library.to_string_lossy()])?;
        let probe = checked(
            hypr,
            &[
                "eval",
                "assert(hl.plugin.hyprbars and hl.plugin.hyprbars.add_button, 'Familiar requires Hyprbars with Lua button support')",
            ],
        );
        let unload = checked(hypr, &["plugin", "unload", &library.to_string_lossy()]);
        probe?;
        unload?;
    }
    let generated = paths.directory.join("titlebars.lua");
    if !state_file.exists() {
        atomic(&generated, b"-- Familiar title bars are disabled.\n")?;
    }
    atomic(
        &state_file,
        &serde_json::to_vec(
            &json!({"library":library,"source":paths.source,"config":paths.config}),
        )
        .map_err(|e| e.to_string())?,
    )?;
    let hook = format!(
        "{}\n\n{BEGIN}\nlocal familiarFile = io.open({}, 'r')\nif familiarFile then\n  familiarFile:close()\n  dofile({})\nend\n{END}\n",
        clean.trim_end(),
        lua(&generated.to_string_lossy()),
        lua(&generated.to_string_lossy())
    );
    atomic(&paths.config, hook.as_bytes())?;
    if args.enable {
        settings["titlebarsEnabled"] = json!(true);
        settings["titlebarStyle"] = json!(args.style);
        settings["titlebarMode"] = json!(args.style);
        settings["dockEnabled"] = json!(true);
        atomic(
            &settings_path,
            &serde_json::to_vec_pretty(&settings).map_err(|e| e.to_string())?,
        )?;
    }
    Ok(
        json!({"state":"ready","message":"Setup complete. Enable Window controls in Familiar Desktop."}),
    )
}
pub fn reconcile(args: &Args, paths: &Paths, hypr: &mut impl Hypr) -> Result<Value> {
    let state_file = paths.directory.join("owner.json");
    let mut state = read_json(&state_file)?;
    if state.as_object().is_some_and(|o| o.is_empty()) {
        return Ok(
            json!({"state":"setup-required","message":"Build the Rust helper and run title-bar setup from Familiar's settings."}),
        );
    }
    if state["source"].as_str() != Some(paths.source.to_string_lossy().as_ref()) {
        return Err("Title bars belong to another Familiar installation; run setup from the installed plugin".into());
    }
    if !text_file(&paths.config)?.contains(BEGIN) {
        return Ok(
            json!({"state":"setup-required","message":"The title-bar configuration hook is missing."}),
        );
    }
    let session = state["session"].as_str().unwrap_or("");
    let token_time = |s: &str| s.split('-').next().unwrap_or("").parse::<u64>().ok();
    if (args.operation == "disable" && args.if_owner && session != args.owner)
        || matches!((token_time(session),token_time(&args.owner)),(Some(a),Some(b)) if b<a)
    {
        return Ok(json!({"state":"off","message":"A newer Familiar instance owns the controls."}));
    }
    let generated = paths.directory.join("titlebars.lua");
    let mut active = false;
    let content = if args.operation == "disable" {
        "-- Familiar title bars are disabled.\n".into()
    } else {
        let library = PathBuf::from(
            state["library"]
                .as_str()
                .ok_or("Invalid title-bar ownership state")?,
        );
        if !library.is_file() {
            return Ok(
                json!({"state":"missing","message":"Hyprbars is missing. Run title-bar setup again."}),
            );
        }
        let policy = (|| {
            let document = read_json(
                &paths
                    .home
                    .join(".local/state/omarchy/current/theme/familiar-desktop.json"),
            )?;
            theme_policy(&document, args)
        })();
        let policy = match policy {
            Ok(v) => v,
            Err(e) => {
                atomic(
                    &generated,
                    b"-- Title bars disabled after a theme validation error.\n",
                )?;
                checked(hypr, &["reload"])?;
                return Err(e);
            }
        };
        active = policy["enabled"] == true;
        if active {
            render(paths, &library, &policy)?
        } else {
            "-- Familiar title bars are disabled by the active theme.\n".into()
        }
    };
    state["session"] = json!(args.owner);
    atomic(
        &state_file,
        &serde_json::to_vec(&state).map_err(|e| e.to_string())?,
    )?;
    if !generated.exists() || text_file(&generated)? != content {
        atomic(&generated, content.as_bytes())?;
        if let Err(e) = checked(hypr, &["reload"]) {
            atomic(
                &generated,
                b"-- Title bars disabled after a reload failure.\n",
            )?;
            return Err(e);
        }
    }
    if active {
        let probe = (|| {
            if !loaded(hypr)? {
                return Err(
                    "Hyprbars did not load; check compatibility with your Hyprland build".into(),
                );
            }
            checked(
                hypr,
                &[
                    "eval",
                    "assert(hl.plugin.hyprbars and hl.plugin.hyprbars.add_button, 'Hyprbars Lua button support is missing')",
                ],
            )?;
            let errors = hypr.command(&["configerrors"])?;
            if !errors.trim().is_empty() {
                return Err(common::clipped(&errors));
            }
            Ok(())
        })();
        if let Err(e) = probe {
            atomic(
                &generated,
                b"-- Title bars disabled after a configuration error.\n",
            )?;
            checked(hypr, &["reload"])?;
            return Err(e);
        }
    }
    Ok(
        json!({"state":if active{"active"}else{"off"},"message":if active && args.mode=="theme"{"Window controls follow the active theme."}else if active{"Window controls are active."}else{"Window controls are off."}}),
    )
}
pub fn remove(paths: &Paths, hypr: &mut impl Hypr) -> Result<Value> {
    let state_file = paths.directory.join("owner.json");
    let state = read_json(&state_file)?;
    if !state.as_object().is_some_and(|o| o.is_empty()) {
        atomic(
            &paths.config,
            strip_hook(&text_file(&paths.config)?)?.as_bytes(),
        )?;
        for p in [paths.directory.join("titlebars.lua"), state_file] {
            match fs::remove_file(p) {
                Ok(()) => {}
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                Err(e) => return Err(e.to_string()),
            }
        }
        checked(hypr, &["reload"])?;
    }
    Ok(json!({"state":"removed","message":"Familiar's title-bar hook was removed."}))
}
pub fn window_action(name: &str, hypr: &mut impl Hypr) -> Result<Value> {
    if !["close", "minimize", "maximize"].contains(&name) {
        return Err("Unknown window action".into());
    }
    let client: Value = serde_json::from_str(&hypr.command(&["-j", "activewindow"])?)
        .map_err(|_| "Hyprland returned invalid window information")?;
    let address = client["address"].as_str().ok_or("No active window")?;
    if !crate::dock::valid_address(address) {
        return Err("No active window".into());
    }
    if name == "minimize" {
        crate::dock::execute("minimize-instance", &[address.to_string()])?;
    } else {
        let dispatch = if name == "close" {
            format!(
                "hl.dsp.window.close({{ window = {} }})",
                lua(&format!("address:{address}"))
            )
        } else {
            format!(
                "hl.dsp.window.fullscreen({{ window = {}, mode = 'maximized', action = 'toggle' }})",
                lua(&format!("address:{address}"))
            )
        };
        checked(hypr, &["dispatch", &dispatch])?;
    }
    Ok(json!({"state":"ok"}))
}
pub fn execute(argv: &[String]) -> Result<Value> {
    let args = Args::parse(argv)?;
    let paths = Paths::system()?;
    let mut hypr = common::SystemHypr;
    if args.operation == "action" {
        return window_action(&args.action, &mut hypr);
    }
    let _lock = common::lock(&paths.directory.join("lock"))?;
    match args.operation.as_str() {
        "setup" => setup(&args, &paths, &mut hypr),
        "remove" => remove(&paths, &mut hypr),
        _ => reconcile(&args, &paths, &mut hypr),
    }
}
