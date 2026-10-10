import QtQuick

BackendRequest {
    route: ["taskbar"]
    choices: ["enable", "reset", "status"]
    resultModes: ["enable", "reset"]
    adapterName: "taskbarAdapter"
    mode: "reset"
    preserveModeOnFailure: true
    failureMessage: "Could not change taskbar layout."
    unreadableMessage: "Could not read taskbar state. Check the installed Familiar backend."
}
