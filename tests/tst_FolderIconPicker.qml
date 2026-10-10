import QtQuick
import QtTest
import "../components"

TestCase {
    id: testCase
    name: "FolderIconPicker"
    width: 500; height: 500
    visible: true
    when: windowShown
    property var chosen: []
    property int dissolutions: 0
    property int dismissals: 0
    Component {
        id: factory
        FolderIconPicker {
            x: 10; y: 10
            icons: ["A", "B", "C"]
            folder: ({id: "work", icon: "B"})
            onIconChosen: function(icon) { testCase.chosen = testCase.chosen.concat([icon]) }
            onDissolveRequested: testCase.dissolutions++
            onDismissRequested: testCase.dismissals++
        }
    }
    function init() { chosen = []; dissolutions = 0; dismissals = 0 }
    function test_choices_data() { return [{tag: "horizontal", vertical: false}, {tag: "vertical", vertical: true}] }
    function test_choices(data) {
        var picker = createTemporaryObject(factory, testCase, {vertical: data.vertical})
        verify(picker !== null)
        picker.resetSelection()
        compare(picker.selectedIndex, 1)
        var first = findChild(picker, "folder-icon-0")
        var second = findChild(picker, "folder-icon-1")
        var dissolve = findChild(picker, "dissolve-folder")
        verify(first !== null && second !== null && dissolve !== null)
        if (data.vertical) {
            compare(picker.width, 36)
            verify(second.y > first.y)
        } else {
            compare(picker.height, 36)
            verify(second.x > first.x)
        }
        mouseClick(first, first.width / 2, first.height / 2)
        compare(chosen[0], "A")
        compare(dismissals, 1)
        mouseClick(second, second.width / 2, second.height / 2)
        compare(chosen[1], "grid", "selecting the current icon restores the folder grid")
        mouseClick(dissolve, dissolve.width / 2, dissolve.height / 2)
        compare(dissolutions, 1)
        compare(dismissals, 3)
    }
    function test_keyboardAndWheelShareSelection() {
        var picker = createTemporaryObject(factory, testCase)
        picker.resetSelection()
        picker.forceActiveFocus()
        keyClick(Qt.Key_Right)
        compare(picker.selectedIndex, 2)
        keyClick(Qt.Key_Return)
        compare(chosen[0], "C")
        keyClick(Qt.Key_Right)
        compare(picker.selectedIndex, 3)
        keyClick(Qt.Key_Space)
        compare(dissolutions, 1)
        picker.wheel(-120)
        compare(picker.selectedIndex, 0, "navigation wraps")
        keyClick(Qt.Key_Escape)
        compare(dismissals, 3)
    }
}
