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
    property bool inputDevicesExpanded: false
    readonly property font activeDeviceFont: Qt.font({
        family: Theme.font.base.family,
        pixelSize: Theme.fontSize.large,
        weight: Theme.font.base.weight
    })
    Material.theme: Material.Dark
    Material.accent: Theme.colors.primary

    Column {
        id: column
        width: parent.width
        spacing: 5

        Rectangle {
            width: parent.width
            height: 82
            color: Theme.colors.surface
            radius: Theme.rounding.normal
            border.width: 1
            border.color: Theme.colors.surfaceVariant

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (!root.devicesExpanded) {
                        root.inputDevicesExpanded = false;
                    }
                    root.devicesExpanded = !root.devicesExpanded;
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                anchors.topMargin: 5
                anchors.bottomMargin: 30
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
                            radius: Theme.rounding.full
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
                                radius: Theme.rounding.full
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
                    radius: Theme.rounding.small
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
                        onClicked: {
                            if (!root.devicesExpanded) {
                                root.inputDevicesExpanded = false;
                            }
                            root.devicesExpanded = !root.devicesExpanded;
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.right: parent.right
                anchors.rightMargin: 55
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                text: Audio.sink ? `Salida · ${Audio.getDisplayName(Audio.sink)}` : "Sin salida activa"
                color: Theme.colors.primary
                font: root.activeDeviceFont
                elide: Text.ElideRight
            }
        }

        // Devices list
        Rectangle {
            width: parent.width
            height: devicesExpanded ? devicesColumn.implicitHeight + 20 : 0
            visible: height > 0
            color: Theme.colors.surface
            radius: Theme.rounding.normal
            clip: true

            border.width: 1
            border.color: Theme.colors.surfaceVariant

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
                        radius: Theme.rounding.normal

                        property bool isActive: Audio.sink?.id === modelData.id

                        color: deviceMouseArea.containsMouse || isActive ? Theme.colors.surfaceVariant : "transparent"

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

        Rectangle {
            width: parent.width
            height: 64
            color: Theme.colors.surface
            radius: Theme.rounding.normal
            border.width: 1
            border.color: Theme.colors.surfaceVariant

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (!root.inputDevicesExpanded) {
                        root.devicesExpanded = false;
                    }
                    root.inputDevicesExpanded = !root.inputDevicesExpanded;
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Entrada"
                        color: Theme.colors.text
                        font: Theme.font.base
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Audio.source ? Audio.getDisplayName(Audio.source) : "Sin entrada activa"
                        color: Theme.colors.primary
                        font: root.activeDeviceFont
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: Theme.rounding.small
                    color: inputExpandButtonMouseArea.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: root.inputDevicesExpanded ? "" : ""
                        color: Theme.colors.text
                        font: Theme.font.base
                    }

                    MouseArea {
                        id: inputExpandButtonMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!root.inputDevicesExpanded) {
                                root.devicesExpanded = false;
                            }
                            root.inputDevicesExpanded = !root.inputDevicesExpanded;
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: inputDevicesExpanded ? sourcesColumn.implicitHeight + 20 : 0
            visible: height > 0
            color: Theme.colors.surface
            radius: Theme.rounding.normal
            clip: true

            border.width: 1
            border.color: Theme.colors.surfaceVariant

            Behavior on height {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            Column {
                id: sourcesColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                Text {
                    width: sourcesColumn.width
                    height: Audio.sources.length === 0 ? 35 : 0
                    visible: Audio.sources.length === 0
                    text: "No hay entradas disponibles"
                    color: Theme.colors.text
                    font: Theme.font.base
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: Audio.sources

                    delegate: Rectangle {
                        required property var modelData

                        width: sourcesColumn.width
                        height: isValidSource ? 35 : 0
                        visible: isValidSource
                        radius: Theme.rounding.normal

                        property bool isActive: Audio.source?.id === modelData.id
                        property bool isValidSource: !modelData.isSink && !modelData.isStream && !!modelData.audio

                        color: sourceMouseArea.containsMouse || isActive ? Theme.colors.surfaceVariant : "transparent"

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: Audio.getDisplayName(modelData)
                            color: parent.isActive ? Theme.colors.primary : Theme.colors.text
                            font: Theme.font.base
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: sourceMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                Audio.setAudioSource(modelData);
                                root.inputDevicesExpanded = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
