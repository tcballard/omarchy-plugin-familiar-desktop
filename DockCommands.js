.pragma library

function quote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

function run(util, args) {
    if (!util || !Array.isArray(args) || args.length === 0) return false;
    var argv = args.map(function(value) { return String(value); });
    if (argv.some(function(value) { return value.indexOf("\x00") !== -1; })) return false;
    if (typeof util.execArgv === "function") {
        util.execArgv(argv);
        return true;
    }
    if (typeof util.execDetached === "function") {
        util.execDetached(argv.map(quote).join(" "));
        return true;
    }
    return false;
}
