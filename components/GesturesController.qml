import QtQuick

BackendRequest {
    route: ["gestures"]
    choices: ["status", "all", "workspace", "desktop", "reset"]
    resultModes: ["all", "workspace", "desktop", "reset"]
    adapterName: "gesturesAdapter"
    failureMessage: "Could not read or apply trackpad preference."
    unreadableMessage: "Could not read trackpad preference. Check the installed Familiar backend."
}
