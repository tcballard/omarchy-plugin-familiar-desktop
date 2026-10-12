import QtQuick
import QtTest
import "../components"

TestCase {
    name: "SafeTextInput"
    when: windowShown
    width: 400
    height: 100
    SafeTextInput { id: editor; width: 300; height: 40 }
    function init() {
        findChild(editor, "clipboardReader").running = false;
        editor.maximumLength = 1024;
        editor.text = "";
        editor.readOnly = false;
        editor.forceActiveFocus();
    }
    function complete(text, code) {
        findChild(editor, "clipboardReader").complete(JSON.stringify({state: "ok", text: text}), code || 0);
    }
    function test_explicitBoundedPaste() {
        var reader = findChild(editor, "clipboardReader");
        verify(!reader.running);
        editor.text = "hello";
        editor.select(0, 5);
        editor.maximumLength = 8;
        editor.requestPaste();
        verify(reader.running);
        complete("<b>\nworld</b>");
        compare(editor.text, "<b> worl");
        compare(editor.textFormat, TextEdit.PlainText);
    }
    function test_failuresDoNotInsertPartialText() {
        editor.text = "keep";
        editor.requestPaste();
        complete("partial", 1);
        compare(editor.text, "keep");
        editor.requestPaste();
        complete("x".repeat(16385));
        compare(editor.text, "keep");
    }
    function test_stalePasteDoesNotOverwriteTyping() {
        editor.text = "old";
        editor.requestPaste();
        editor.text = "new";
        complete("clipboard");
        compare(editor.text, "new");
    }
    function test_readOnlyDoesNotRequest() {
        editor.readOnly = true;
        editor.requestPaste();
        verify(!findChild(editor, "clipboardReader").running);
    }
}
