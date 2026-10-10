import QtQuick
import QtTest
import "../components"

TestCase {
    id: testCase
    name: "PreferenceToggle"
    width: 400; height: 150
    visible: true
    when: windowShown
    property bool savedValue: false
    property var requests: []
    Component {
        id: factory
        PreferenceToggle {
            width: 350; height: implicitHeight
            label: "Example preference"
            description: "Owned by the service"
            checked: testCase.savedValue
            onToggled: function(value) { testCase.requests = testCase.requests.concat([value]) }
        }
    }
    function init() { savedValue = false; requests = [] }
    function test_requestsDoNotBreakTheOwnerBinding() {
        var row = createTemporaryObject(factory, testCase)
        mouseClick(row, 20, 20)
        compare(requests, [true])
        compare(row.checked, false)
        savedValue = true
        compare(row.checked, true)
        compare(requests.length, 1, "external updates do not write back")
        row.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(requests, [true, false])
    }
    function test_disabledControlDoesNotRequestChanges() {
        var row = createTemporaryObject(factory, testCase, {enabled: false})
        mouseClick(row, 20, 20)
        row.requestToggle()
        compare(requests.length, 0)
    }
}
