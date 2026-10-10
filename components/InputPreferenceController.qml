import QtQuick

BackendRequest {
    required property string kind
    route: ["input-preference", kind]
    choices: ["resize", "command"].indexOf(kind) >= 0 ? ["enable", "reset", "status"] : []
    resultModes: ["enable", "reset"]
    adapterName: "inputPreferenceAdapter"
}
