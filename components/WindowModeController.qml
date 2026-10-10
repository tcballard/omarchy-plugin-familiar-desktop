import QtQuick

BackendRequest {
    route: ["window-mode"]
    choices: ["status", "floating", "tiling", "reset"]
    resultModes: ["floating", "tiling", "reset"]
    adapterName: "windowModeAdapter"
    failureMessage: "Could not read or apply window mode preference."
    unreadableMessage: "Could not read window mode preference. Check the installed Familiar backend."
    function argumentsFor(choice) {
        return choice === "floating" || choice === "tiling"
            ? ["window-mode", "switch", choice] : ["window-mode", choice]
    }
}
