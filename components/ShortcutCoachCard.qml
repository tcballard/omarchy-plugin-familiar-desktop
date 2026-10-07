import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../ShortcutLabels.js" as ShortcutLabels

Rectangle {
    id: root
    required property var controller
    readonly property var lesson: controller.activeLesson
    implicitWidth: Style.space(360)
    implicitHeight: body.implicitHeight + Style.space(28)
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: Color.popups.border
    Accessible.role: Accessible.AlertMessage
    Accessible.name: lesson ? lesson.title + ". " + ShortcutLabels.format(lesson.shortcut, controller.labelStyle) : ""

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(14) }
        spacing: Style.space(8)
        Text {
            Layout.fillWidth: true
            text: root.lesson ? root.lesson.hintTitle : ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.space(14)
            font.bold: true
            color: Color.popups.text
        }
        Text {
            objectName: "coach-shortcut"
            Layout.fillWidth: true
            text: root.lesson ? "Next time: " + ShortcutLabels.format(root.lesson.shortcut, root.controller.labelStyle) : ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.space(16)
            font.bold: true
            color: Color.popups.text
        }
        Text {
            Layout.fillWidth: true
            text: root.lesson ? root.lesson.description : ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            color: Color.popups.text
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            ActionButton {
                objectName: "coach-remind-later"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitWidth: 0
                text: "Remind me later"
                onClicked: root.controller.dismiss()
            }
            ActionButton {
                objectName: "coach-got-it"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitWidth: 0
                text: "Got it"
                selected: true
                onClicked: if (root.lesson) root.controller.markLearned(root.lesson.id)
            }
        }
    }
}
