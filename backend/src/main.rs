use familiar_desktop::{
    caps_lock, common, desktop, dock, gestures, input_preferences, titlebars, window_mode,
};
use serde_json::json;
fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().is_some_and(|s| s == "--version") {
        println!("familiar-desktop {}", env!("CARGO_PKG_VERSION"));
        return;
    }
    let result=match args.first().map(String::as_str) {
        Some("input-preference")=>input_preferences::execute(&args[1..]),
        Some("gestures")=>gestures::execute(&args[1..]),
        Some("window-mode")=>window_mode::execute(&args[1..]),
        Some("caps-lock")=>caps_lock::execute(&args[1..]),
        Some("desktop")=>desktop::execute(&args[1..]),
        Some("titlebars")=>titlebars::execute(&args[1..]),
        Some("dock")=>args.get(1).ok_or_else(||"Choose a dock operation".to_string()).and_then(|mode|dock::execute(mode,&args[2..])),
        Some("badges") if args.get(1).is_some_and(|s|s=="save")=>common::home().and_then(|home|{
            if args.len() != 3 || args[2] != "--stdin" {
                return Err("Use badges save --stdin".into());
            }
            common::save_badges_from_reader(&home, std::io::stdin().lock())
        }),
        _=>Err("Usage: familiar-desktop caps-lock <normal|compose|reset|status> | titlebars <setup|apply|disable|remove|action> | dock <operation> | badges save --stdin".into()),
    };
    match result {
        Ok(value) => println!("{value}"),
        Err(e) => {
            println!(
                "{}",
                json!({"state":"failed","message":common::clipped(&e)})
            );
            std::process::exit(1);
        }
    }
}
