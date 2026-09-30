use familiar_desktop::{common, dock, titlebars};
use serde_json::json;
fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().is_some_and(|s| s == "--version") {
        println!("familiar-desktop {}", env!("CARGO_PKG_VERSION"));
        return;
    }
    let result=match args.first().map(String::as_str) {
        Some("titlebars")=>titlebars::execute(&args[1..]),
        Some("dock")=>args.get(1).ok_or_else(||"Choose a dock operation".to_string()).and_then(|mode|dock::execute(mode,&args[2..])),
        Some("badges") if args.get(1).is_some_and(|s|s=="save")=>common::home().and_then(|home|common::save_badges(&home,args.get(2).ok_or("Provide badge JSON")?)),
        _=>Err("Usage: familiar-desktop titlebars <setup|apply|disable|remove|action> | dock <operation> | badges save <json>".into()),
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
