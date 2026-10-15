import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

import qs.common
import qs.common.components.icons
import qs.services

Item {
    id: root

    implicitWidth: parent.width
    implicitHeight: column.implicitHeight

    property string expandedSection: ""

    Column {
        id: column
        width: parent.width
        spacing: 6

        Rectangle {
            width: parent.width
            height: outputColumn.implicitHeight + 24
            radius: Theme.rounding.large
            color: Theme.colors.surface
            border.width: 1
            border.color: Theme.colors.surfaceVariant

            Column {
                id: outputColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    id: outputHeader
                    width: parent.width
                    spacing: 0

                    IconSlot {
                        id: outputIcon
                        icon: Audio.icon
                        iconColor: Theme.colors.primary
                        gapAfter: 8
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.rightMargin: 8
                        spacing: 1

                        Text {
                            text: "Salida"
                            color: Theme.colors.overlay
                            font: Theme.font.overlay
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Audio.sink ? Audio.getDisplayName(Audio.sink) : "Sin salida activa"
                            color: Theme.colors.text
                            font: Theme.font.overlay
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        id: outputPercentage
                        text: `${Math.round((Audio.volume || 0) * 100)}%`
                        color: Theme.colors.primary
                        font: Theme.font.overlay
                    }

                    IconSlot {
                        id: outputArrow
                        icon: root.expandedSection === "output" ? "" : ""
                        iconColor: Theme.colors.overlay
                        iconFont: Theme.font.icon
                        gapBefore: 8
                        gapAfter: 0
                        interactive: true
                        onClicked: root.expandedSection = root.expandedSection === "output" ? "" : "output"
                    }
                }

                Item {
                    x: outputIcon.x + outputIcon.width
                    width: outputPercentage.x + outputPercentage.width - x
                    height: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
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
                    }

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

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => root.updateVolume(mouse.x, width)
                        onPositionChanged: mouse => {
                            if (pressed) root.updateVolume(mouse.x, width);
                        }
                        onWheel: wheel => {
                            if (wheel.angleDelta.y > 0) Audio.increaseVolume();
                            else Audio.decreaseVolume();
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.expandedSection = root.expandedSection === "output" ? "" : "output"
            }
        }

        Rectangle {
            width: parent.width
            height: root.expandedSection === "output" ? sinksColumn.implicitHeight + 20 : 0
            visible: height > 0
            radius: Theme.rounding.large
            color: Theme.colors.surface
            border.width: 1
            border.color: Theme.colors.surfaceVariant
            clip: true

            Behavior on height {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            Column {
                id: sinksColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                Repeater {
                    model: Audio.sinks

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool validSink: modelData.isSink && !!modelData.audio
                        readonly property bool activeSink: Audio.sink?.id === modelData.id

                        width: sinksColumn.width
                        height: validSink ? 38 : 0
                        visible: validSink
                        radius: Theme.rounding.normal
                        color: activeSink || sinkMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: Audio.getDisplayName(modelData)
                                color: activeSink ? Theme.colors.primary : Theme.colors.text
                                font: Theme.font.overlay
                                elide: Text.ElideRight
                            }

                            IconSlot {
                                icon: activeSink ? "" : ""
                                iconColor: Theme.colors.primary
                                gapBefore: 8
                                gapAfter: 0
                            }
                        }

                        MouseArea {
                            id: sinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Audio.setAudioSink(modelData);
                                root.expandedSection = "";
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 64
            radius: Theme.rounding.large
            color: Theme.colors.surface
            border.width: 1
            border.color: Theme.colors.surfaceVariant

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0

                IconSlot {
                    icon: "󰍬"
                    iconColor: Theme.colors.primary
                    gapAfter: 8
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: 8
                    spacing: 1

                    Text {
                        text: "Entrada"
                        color: Theme.colors.overlay
                        font: Theme.font.overlay
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Audio.source ? Audio.getDisplayName(Audio.source) : "Sin entrada activa"
                        color: Theme.colors.text
                        font: Theme.font.overlay
                        elide: Text.ElideRight
                    }
                }

                IconSlot {
                    icon: root.expandedSection === "input" ? "" : ""
                    iconColor: Theme.colors.overlay
                    iconFont: Theme.font.icon
                    gapBefore: 8
                    gapAfter: 0
                    interactive: true
                    onClicked: root.expandedSection = root.expandedSection === "input" ? "" : "input"
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.expandedSection = root.expandedSection === "input" ? "" : "input"
            }
        }

        Rectangle {
            width: parent.width
            height: root.expandedSection === "input" ? sourcesColumn.implicitHeight + 20 : 0
            visible: height > 0
            radius: Theme.rounding.large
            color: Theme.colors.surface
            border.width: 1
            border.color: Theme.colors.surfaceVariant
            clip: true

            Behavior on height {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            Column {
                id: sourcesColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                Repeater {
                    model: Audio.sources

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool validSource: !modelData.isSink && !modelData.isStream && !!modelData.audio
                        readonly property bool activeSource: Audio.source?.id === modelData.id

                        width: sourcesColumn.width
                        height: validSource ? 38 : 0
                        visible: validSource
                        radius: Theme.rounding.normal
                        color: activeSource || sourceMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: Audio.getDisplayName(modelData)
                                color: activeSource ? Theme.colors.primary : Theme.colors.text
                                font: Theme.font.overlay
                                elide: Text.ElideRight
                            }

                            IconSlot {
                                icon: activeSource ? "" : ""
                                iconColor: Theme.colors.primary
                                gapBefore: 8
                                gapAfter: 0
                            }
                        }

                        MouseArea {
                            id: sourceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Audio.setAudioSource(modelData);
                                root.expandedSection = "";
                            }
                        }
                    }
                }
            }
        }
    }

    function updateVolume(position, trackWidth) {
        if (Pipewire.defaultAudioSink) {
            Audio.setVolume(Math.max(0, Math.min(1, position / trackWidth)));
        }
    }
}
