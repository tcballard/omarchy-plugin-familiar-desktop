import QtQuick
import Quickshell.Io

// Qt 6.12 TextInput fetches clipboard text in q_canPasteChanged(). PlainText
// TextEdit checks MIME availability only. Never invoke its native paste path.
TextEdit {
    id: editor
    textFormat: TextEdit.PlainText
    wrapMode: TextEdit.NoWrap
    property int maximumLength: 1024
    property string pasteError: ""
    property string requestedText: ""
    property int requestedStart: 0
    property int requestedEnd: 0
    readonly property bool pasteBusy: reader.running
    signal editingFinished()
    onActiveFocusChanged: if (!activeFocus) editingFinished()

    function requestPaste() {
        if (readOnly || !activeFocus || reader.running) return;
        pasteError = "";
        requestedText = text;
        requestedStart = selectionStart;
        requestedEnd = selectionEnd;
        reader.running = true;
    }
    function applyPaste(code, data) {
        if (code !== 0 || !activeFocus || readOnly || text !== requestedText
                || selectionStart !== requestedStart || selectionEnd !== requestedEnd) {
            pasteError = "Paste failed or the editor lost focus.";
            return;
        }
        try {
            var value = JSON.parse(data);
            if (value.state !== "ok" || typeof value.text !== "string" || value.text.length > 16384)
                throw new Error("Invalid clipboard result");
            var start = selectionStart;
            var end = selectionEnd;
            var room = Math.max(0, maximumLength - (text.length - (end - start)));
            var incoming = value.text.replace(/[\r\n\u2028\u2029]/g, " ").slice(0, room);
            remove(start, end);
            insert(start, incoming);
        } catch (e) {
            pasteError = "Clipboard text could not be pasted.";
        }
    }
    onTextChanged: {
        var bounded = text.replace(/[\r\n\u2028\u2029]/g, " ").slice(0, maximumLength);
        if (text !== bounded) text = bounded;
    }
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (event.matches(StandardKey.Paste)) {
            event.accepted = true;
            requestPaste();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            editingFinished();
        }
    }
    // Block TextEdit's native primary-selection paste (middle mouse).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: editor.requestPaste()
    }
    Process {
        id: reader
        objectName: "clipboardReader"
        command: [Qt.resolvedUrl("../bin/familiar-desktop").toString().replace(/^file:\/\//, ""), "clipboard", "paste"]
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: function(code, status) { editor.applyPaste(code, output.text); }
    }
}
