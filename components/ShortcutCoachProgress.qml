pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../ShortcutCoach.js" as Coach
import "../ShortcutLabels.js" as ShortcutLabels

ColumnLayout {
    id: root
    property var controller: null
    property bool confirmingReset: false
    readonly property bool ready: !!controller && controller.ready
    readonly property var progress: controller ? controller.progress : ({learned: 0, total: 0, fraction: 0})
    spacing: Style.space(8)
    onVisibleChanged: confirmingReset = false
    Text {
        Layout.fillWidth: true
        text: "Shortcut Coach"
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: Style.space(14)
        font.bold: true
        color: Color.popups.text
    }
    Text {
        Layout.fillWidth: true
        text: "Learn shortcuts while using Familiar with the mouse. Got it marks a shortcut as learned."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.space(12)
        color: Color.popups.text
    }
    ActionButton {
        objectName: "coach-enabled"
        Layout.fillWidth: true
        text: (root.controller && root.controller.hintsEnabled ? "✓  " : "○  ") + "Show keyboard shortcut hints"
        selected: !!root.controller && root.controller.hintsEnabled
        enabled: root.ready
        Accessible.role: Accessible.CheckBox
        Accessible.checkable: true
        Accessible.checked: selected
        onClicked: root.controller.setEnabled(!root.controller.hintsEnabled)
    }
    Text {
        Layout.fillWidth: true
        text: "Keyboard progress · " + root.progress.learned + " / " + root.progress.total + " learned"
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: Style.space(12)
        color: Color.popups.text
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.space(6)
        radius: height / 2
        color: Color.popups.border
        Accessible.role: Accessible.ProgressBar
        Accessible.name: "Keyboard progress"
        Accessible.description: root.progress.learned + " of " + root.progress.total + " shortcuts learned"
        Rectangle {
            width: parent.width * root.progress.fraction
            height: parent.height
            radius: parent.radius
            color: Color.accent
        }
    }
    Repeater {
        model: root.controller ? root.controller.lessons : []
        delegate: RowLayout {
            id: lessonRow
            required property var modelData
            readonly property bool learned: Coach.lessonState(root.controller.learningState.lessons[modelData.id]).learned
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: (lessonRow.learned ? "✓  " : "○  ") + lessonRow.modelData.title + "\n" + ShortcutLabels.format(lessonRow.modelData.shortcut, root.controller.labelStyle)
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.space(12)
                color: Color.popups.text
            }
            ActionButton {
                objectName: "coach-learn-" + lessonRow.modelData.id
                implicitWidth: Style.space(72)
                implicitHeight: Style.space(32)
                text: lessonRow.learned ? "Learned" : "Got it"
                selected: lessonRow.learned
                enabled: root.ready && !lessonRow.learned
                onClicked: root.controller.markLearned(lessonRow.modelData.id)
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.progress.total === 0
        text: "No supported shortcuts are available. Mouse controls work as usual."
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.space(12)
        color: Color.popups.text
    }
    ActionButton {
        objectName: "coach-reset"
        Layout.fillWidth: true
        text: "Reset learning progress…"
        enabled: root.ready
        visible: !root.confirmingReset
        onClicked: root.confirmingReset = true
    }
    RowLayout {
        Layout.fillWidth: true
        visible: root.confirmingReset
        ActionButton {
            objectName: "coach-reset-cancel"
            Layout.fillWidth: true
            text: "Keep progress"
            onClicked: root.confirmingReset = false
        }
        ActionButton {
            objectName: "coach-reset-confirm"
            Layout.fillWidth: true
            text: "Confirm reset"
            enabled: root.ready
            onClicked: { root.controller.reset(); root.confirmingReset = false }
        }
    }
    Text {
        Layout.fillWidth: true
        text: root.controller && root.controller.store ? root.controller.store.message : "Familiar service is unavailable."
        visible: text.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.space(12)
        color: Color.popups.text
    }
}
