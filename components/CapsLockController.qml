import QtQuick

BackendRequest {
    route: ["caps-lock"]
    choices: ["status", "normal", "compose", "reset"]
    resultModes: ["normal", "compose", "reset"]
    adapterName: "capsLockAdapter"
    failureMessage: "Could not read or apply Caps Lock preference."
    unreadableMessage: "Could not read Caps Lock preference. Check the installed Familiar backend."
}
