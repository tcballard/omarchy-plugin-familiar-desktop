import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

Rectangle {
    id: root
    property string page: "general"
    property string section: ""
    readonly property var sections: ({
        dock: [{key: "appearance", title: "Appearance"}, {key: "visibility", title: "Visibility"}, {key: "extras", title: "Extras"}],
        windows: [{key: "layout", title: "Layout"}, {key: "titlebars", title: "Title bars"}, {key: "resizing", title: "Resizing"}],
        keyboard: [{key: "keys", title: "Caps Lock"}, {key: "shortcuts", title: "Shortcuts"}, {key: "gestures", title: "Trackpad"}]
    })
    readonly property var currentSections: sections[page] || []
    function shows(pageKey, sectionKey) { return page === pageKey && section === sectionKey }
    property real contentHeight: 0
    default property alias contents: contentHolder.data
    signal dismissed()
    readonly property real inset: Style.space(20)
    readonly property bool compact: width < Style.space(620)
    readonly property var pages: [
        {key: "general", title: "General", glyph: "▦", detail: "Your starting layout and desktop actions."},
        {key: "dock", title: "Dock", glyph: "▤", detail: "Apps, visibility and the way your dock behaves."},
        {key: "windows", title: "Windows", glyph: "□", detail: "Window layout, title bars and mouse resizing."},
        {key: "keyboard", title: "Input", glyph: "⌨", detail: "Caps Lock, editing shortcuts and trackpad gestures."},
        {key: "help", title: "Getting Started", glyph: "?", detail: "Your shortcuts and useful system tools."}
    ]
    readonly property var current: pages.filter(p => p.key === page)[0] || pages[0]
    radius: Style.cornerRadius
    color: Commons.Color.popups.background
    border.width: 1
    border.color: Commons.Color.popups.border
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => { wheel.accepted = true }
    }
    onPageChanged: {
        section = sections[page] ? sections[page][0].key : ""
        resetScroll()
    }
    onSectionChanged: resetScroll()
    Component.onCompleted: section = sections[page] ? sections[page][0].key : ""
    function resetScroll() { scroller.contentY = 0 }

    Rectangle {
        id: sidebar
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left; margins: 1 }
        width: root.compact ? Style.space(58) : Style.space(190)
        radius: root.radius
        color: Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent)
        ColumnLayout {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Style.space(10) }
            spacing: Style.space(6)
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(58)
                text: root.compact ? "󰟀" : "󰟀  Familiar"
                verticalAlignment: Text.AlignVCenter
                font.family: Style.font.family
                font.pixelSize: Style.space(15)
                font.bold: true
                color: Commons.Color.popups.text
                elide: Text.ElideRight
            }
            Repeater {
                id: navigation
                model: root.pages
                delegate: AbstractButton {
                    id: nav
                    required property var modelData
                    required property int index
                    objectName: "settings-nav-" + modelData.key
                    Layout.fillWidth: true
                    implicitHeight: Style.space(42)
                    checkable: true
                    checked: root.page === modelData.key
                    Accessible.name: modelData.title
                    focusPolicy: Qt.StrongFocus
                    onClicked: root.page = modelData.key
                    Keys.onDownPressed: { root.page = root.pages[(index + 1) % root.pages.length].key; navigation.itemAt((index + 1) % root.pages.length).forceActiveFocus() }
                    Keys.onUpPressed: { root.page = root.pages[(index + root.pages.length - 1) % root.pages.length].key; navigation.itemAt((index + root.pages.length - 1) % root.pages.length).forceActiveFocus() }
                    ToolTip.visible: hovered && root.compact
                    ToolTip.text: modelData.title
                    background: Rectangle {
                        radius: Style.space(6)
                        color: nav.checked ? Commons.Color.accent : nav.hovered || nav.down ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
                        border.width: nav.activeFocus ? 2 : 0
                        border.color: Commons.Color.popups.text
                    }
                    contentItem: Text {
                        text: root.compact ? nav.modelData.glyph : nav.modelData.title
                        leftPadding: root.compact ? 0 : Style.space(12)
                        horizontalAlignment: root.compact ? Text.AlignHCenter : Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        font.family: Style.font.family
                        font.pixelSize: Style.space(12)
                        font.bold: nav.checked
                        color: nav.checked ? Commons.Color.background : Commons.Color.popups.text
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    Item {
        id: pane
        anchors { top: parent.top; bottom: parent.bottom; left: sidebar.right; right: parent.right; margins: root.inset }
        ColumnLayout {
            id: heading
            anchors { top: parent.top; left: parent.left; right: parent.right }
            spacing: Style.space(6)
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: root.current.title
                    font.family: Style.font.family
                    font.pixelSize: Style.space(21)
                    font.bold: true
                    color: Commons.Color.popups.text
                    elide: Text.ElideRight
                }
                ActionButton {
                    objectName: "settings-close"
                    text: "×"
                    Accessible.name: "Close settings"
                    implicitWidth: Style.space(34)
                    implicitHeight: Style.space(34)
                    onClicked: root.dismissed()
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.current.detail
                wrapMode: Text.WordWrap
                font.family: Style.font.family
                font.pixelSize: Style.space(12)
                color: Commons.Color.popups.text
                opacity: 0.7
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.currentSections.length > 0
                spacing: Style.space(6)
                Repeater {
                    id: sectionNavigation
                    model: root.currentSections
                    delegate: ActionButton {
                        required property var modelData
                        required property int index
                        objectName: "settings-section-" + modelData.key
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        implicitWidth: 0
                        text: modelData.title
                        selected: root.section === modelData.key
                        onClicked: root.section = modelData.key
                        Keys.onRightPressed: {
                            var next = (index + 1) % root.currentSections.length
                            root.section = root.currentSections[next].key
                            sectionNavigation.itemAt(next).forceActiveFocus()
                        }
                        Keys.onLeftPressed: {
                            var previous = (index + root.currentSections.length - 1) % root.currentSections.length
                            root.section = root.currentSections[previous].key
                            sectionNavigation.itemAt(previous).forceActiveFocus()
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Style.space(10)
                implicitHeight: 1
                color: Commons.Color.popups.border
            }
        }
        Flickable {
            id: scroller
            objectName: "settings-scroll"
            anchors { top: heading.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: root.inset }
            clip: true
            contentWidth: width
            contentHeight: root.contentHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Item {
                id: contentHolder
                width: scroller.width - Style.space(12)
                height: root.contentHeight
            }
        }
    }
}
