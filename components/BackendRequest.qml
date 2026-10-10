import QtQuick
import Quickshell.Io

// Serialized JSON requests for ordinary preference controllers. Titlebar
// reconciliation and streaming setup keep their own specialized lifecycles.
Item {
    id: request
    property string helper: Qt.resolvedUrl("../bin/familiar-desktop").toString().replace(/^file:\/\//, "")
    property var route: []
    property var choices: []
    property var resultModes: []
    property string adapterName: "backendAdapter"
    property string failureMessage: "Could not apply preference."
    property string unreadableMessage: "Could not read preference. Check the installed Familiar backend."
    property bool preserveModeOnFailure: false
    property string mode: ""
    property string message: ""
    property string operation: ""
    readonly property bool busy: adapter.running
    signal completed(string operation)

    function argumentsFor(choice) {
        return route.concat([choice]);
    }
    function run(choice) {
        if (busy || choices.indexOf(choice) < 0)
            return false;
        operation = choice;
        message = "";
        adapter.command = [helper].concat(argumentsFor(choice));
        adapter.running = true;
        return true;
    }
    function fail(text) {
        if (!preserveModeOnFailure)
            mode = "";
        message = String(text).slice(0, 300);
    }
    function finish(code, text) {
        try {
            var result = JSON.parse(text);
            if (code !== 0 || result.state !== "ok" || resultModes.indexOf(result.mode) < 0) {
                fail(result.message || failureMessage);
                return;
            }
            mode = result.mode;
            message = String(result.message || "").slice(0, 300);
            completed(operation);
        } catch (e) {
            fail(unreadableMessage);
        }
    }
    Process {
        id: adapter
        objectName: request.adapterName
        stdout: StdioCollector {
            id: output
            waitForEnd: true
        }
        onExited: function (code, status) {
            request.finish(code, output.text);
        }
    }
}
