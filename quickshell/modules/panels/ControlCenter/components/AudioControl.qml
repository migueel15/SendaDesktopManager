import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell
import Quickshell.Io
import QtQuick.Controls
import QtQuick.Controls.Material

import qs.common
import qs.services

Item {
    id: root

    implicitWidth: parent.width
    implicitHeight: column.implicitHeight

    property bool devicesExpanded: false
    Material.theme: Material.Dark
    Material.accent: Theme.colors.primary

    Column {
        id: column
        width: parent.width
        spacing: 10

        Rectangle {
            width: parent.width
            height: 60
            color: Theme.colors.surface
            radius: Theme.barBorderRadius

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: root.devicesExpanded = !root.devicesExpanded
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10

                // Volume icon and slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: Audio.icon
                        color: Theme.colors.primary
                        font: Theme.font.base
                    }

                    // Volume slider
                    Item {
                        Layout.fillWidth: true
                        height: 20

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Theme.colors.surfaceVariant

                            Rectangle {
                                width: parent.width * (Audio.volume || 0)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.colors.primary
                            }

                            // Slider handle (circle)
                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: Theme.colors.white
                                border.color: Theme.colors.primary
                                border.width: 2
                                x: (parent.width * (Audio.volume || 0)) - width / 2
                                y: parent.height / 2 - height / 2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => updateVolume(mouse.x)
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    updateVolume(mouse.x);
                                }
                            }

                            function updateVolume(x) {
                                if (Pipewire.defaultAudioSink) {
                                    const volume = Math.max(0, Math.min(1, x / width));
                                    Audio.setVolume(volume);
                                }
                            }

                            onWheel: wheel => {
                                if (wheel.angleDelta.y > 0) {
                                    Audio.increaseVolume();
                                } else {
                                    Audio.decreaseVolume();
                                }
                            }
                        }
                    }

                    Text {
                        text: Math.round((Audio.volume || 0) * 100) + "%"
                        color: Theme.colors.text
                        font: Theme.font.base
                    }
                }

                // Expand button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 6
                    color: expandButtonMouseArea.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: root.devicesExpanded ? "" : ""
                        color: Theme.colors.text
                        font: Theme.font.base
                    }

                    MouseArea {
                        id: expandButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.devicesExpanded = !root.devicesExpanded
                    }
                }
            }
        }

        // Devices list
        Rectangle {
            width: parent.width
            height: devicesExpanded ? devicesColumn.implicitHeight + 20 : 0
            visible: height > 0
            color: Theme.colors.surface
            radius: Theme.barBorderRadius
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            Column {
                id: devicesColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                Repeater {
                    model: Audio.sinks

                    delegate: Rectangle {
                        required property var modelData

                        width: devicesColumn.width
                        height: isValidSink ? 35 : 0
                        visible: isValidSink
                        radius: 6
                        color: deviceMouseArea.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                        property bool isActive: Audio.sink?.id === modelData.id

                        property bool isValidSink: modelData.isSink && !!modelData.audio

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: {
                                Audio.getDisplayName(modelData);
                            }
                            color: parent.isActive ? Theme.colors.primary : Theme.colors.text
                            font: Theme.font.base
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: deviceMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                // Audio.changeDefaultSink(modelData);
                                Audio.setAudioSink(modelData);
                                root.devicesExpanded = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
