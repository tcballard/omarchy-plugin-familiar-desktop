import QtQuick
import qs.Commons
import ".."

                    Item {
                        id: slot
                        onWidgetRegistryRevisionChanged: widgetLoader.applyWidgetSource()
                        required property string modelData
                        required property int index
                        required property var actions
                        required property real offset
                        signal clockUpdated(string text)
                        required property bool isVertical
                        required property real clockSlotWidth
                        required property real slotSize
                        required property real iconBaseSize
                        required property bool isEditMode
                        required property string clockDisplayText
                        required property string currentHourString
                        required property string currentMinutePart
                        required property int widgetIconRevision
                        required property real pipewireSinkVolume
                        required property bool pipewireSinkMuted
                        required property bool pipewireSourceMuted
                        required property real upowerBatteryPercentage
                        required property int upowerBatteryState
                        required property int widgetRegistryRevision

                        readonly property real widgetSlotDimension: (modelData === "omarchy.clock" && !slot.isVertical) ? slot.clockSlotWidth : slot.slotSize
                        readonly property real widgetPos: slot.offset
                        x: slot.isVertical ? 0 : widgetPos
                        y: slot.isVertical ? widgetPos : 0
                        width: slot.isVertical ? slot.slotSize : widgetSlotDimension
                        height: slot.isVertical ? widgetSlotDimension : slot.slotSize
                        z: 1

                        Item {
                            id: widgetWrapper
                            anchors.centerIn: parent
                            width: (modelData === "omarchy.clock" && !slot.isVertical) ? (slot.width - 10) : slot.iconBaseSize
                            height: (modelData === "omarchy.clock" && slot.isVertical) ? (slot.slotSize - 8) : slot.iconBaseSize
                            scale: slot.isEditMode ? 0.82 : 1.0
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            Text {
                                id: clockHorizontalLabel
                                visible: modelData === "omarchy.clock" && !slot.isVertical
                                anchors.centerIn: parent
                                text: (widgetLoader.item && widgetLoader.item.displayText) ? widgetLoader.item.displayText : (slot.clockDisplayText !== "" ? slot.clockDisplayText : Qt.formatDateTime(new Date(), "dddd HH:mm"))
                                textFormat: Text.PlainText
                                font.family: Style.font.family
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: widgetSlotMouse.containsMouse ? Color.accent : Color.bar.text
                                renderType: Text.CurveRendering
                                font.hintingPreference: Font.PreferNoHinting
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Column {
                                id: clockVerticalCol
                                visible: modelData === "omarchy.clock" && slot.isVertical
                                anchors.centerIn: parent
                                spacing: 1

                                Repeater {
                                    model: [slot.currentHourString, slot.currentMinutePart]

                                    Text {
                                        required property string modelData
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData
                                        textFormat: Text.PlainText
                                        font.family: Style.font.family
                                        font.pixelSize: modelData.length > 3 ? 9 : 10
                                        font.weight: Font.Medium
                                        color: widgetSlotMouse.containsMouse ? Color.accent : Color.bar.text
                                        renderType: Text.CurveRendering
                                        font.hintingPreference: Font.PreferNoHinting
                                    }
                                }
                            }

                            DockGlyph {
                                id: widgetGlyph
                                visible: modelData !== "omarchy.clock"
                                anchors.centerIn: parent
                                width: slot.iconBaseSize
                                height: slot.iconBaseSize
                                text: {
                                    var _rev = slot.widgetIconRevision
                                    var _v = slot.pipewireSinkVolume
                                    var _m = slot.pipewireSinkMuted
                                    var _sm = slot.pipewireSourceMuted
                                    var _bp = slot.upowerBatteryPercentage
                                    var _bs = slot.upowerBatteryState
                                    var it = widgetLoader.item
                                    var _ic = it ? (it.icon || it.displayText || it.playIcon || "") : ""
                                    return slot.actions.iconFor(modelData, it)
                                }
                                fontFamily: (widgetLoader.item && widgetLoader.item.fontFamily) ? widgetLoader.item.fontFamily : ((widgetLoader.item && widgetLoader.item.font && widgetLoader.item.font.family) ? widgetLoader.item.font.family : Style.font.family)
                                fontSize: 22
                                color: widgetSlotMouse.containsMouse ? Color.accent : Color.bar.text
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Loader {
                                id: widgetLoader
                                anchors.fill: parent
                                opacity: 0.0
                                // source and sourceComponent clear one another, so pick one
                                // imperatively instead of binding both. This runs on every
                                // registry revision (dozens during shell start-up); re-assigning
                                // an unchanged source would still tear the item down, so it
                                // returns early when nothing changed.
                                function applyWidgetSource() {
                                    var comp = slot.actions.componentFor(modelData)
                                    if (comp) {
                                        if (sourceComponent === comp) return
                                        source = ""
                                        sourceComponent = comp
                                        return
                                    }
                                    var url = slot.actions.sourceFor(modelData)
                                    if (url !== "" && String(source) === url) return
                                    sourceComponent = null
                                    source = url
                                }
                                Component.onCompleted: applyWidgetSource()

                                onLoaded: {
                                    if (item) {
                                        slot.actions.attach(item, modelData, slot)
                                        if (modelData === "omarchy.clock") {
                                            if (item.displayText !== undefined) slot.clockUpdated(item.displayText)
                                            if (item.displayTextChanged) {
                                                item.displayTextChanged.connect(function() {
                                                    slot.clockUpdated(item.displayText)
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: widgetSlotMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: slot.isEditMode ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                slot.actions.activate(modelData, widgetLoader.item, slot, mouse)
                            }
                        }
                    }
