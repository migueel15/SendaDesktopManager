import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

import qs.common
import qs.common.components.controls
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
        // Selectors attach under their card; the input card uses a spacer.
        spacing: 0

        Rectangle {
            width: parent.width
            height: outputColumn.implicitHeight + 24
            radius: Theme.card.radius
            color: Theme.card.fill
            border.width: Theme.card.borderWidth
            border.color: Theme.card.borderColor

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
                    height: volumeSlider.implicitHeight

                    // Same slider as Settings; the percentage is shown beside it.
                    ZendaSlider {
                        id: volumeSlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 100; stepSize: 1
                        showValue: false
                        value: Math.round((Audio.volume || 0) * 100)
                        onMoved: value => root.updateVolume(value, 100)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.expandedSection = root.expandedSection === "output" ? "" : "output"
            }
        }

        ZendaExpandPanel {
            id: outputDropdown
            expanded: root.expandedSection === "output"
            contentHeight: sinksColumn.implicitHeight + 20

            Column {
                id: sinksColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                Repeater {
                    model: Audio.sinks

                    delegate: ZendaListItem {
                        required property var modelData
                        width: sinksColumn.width
                        visible: modelData.isSink && !!modelData.audio
                        height: visible ? implicitHeight : 0
                        selected: Audio.sink?.id === modelData.id
                        leadingIcon: "󰓃"
                        text: Audio.getDisplayName(modelData)
                        onClicked: {
                            Audio.setAudioSink(modelData);
                            root.expandedSection = "";
                        }
                    }
                }
            }
        }

        Item {
            width: 1
            height: 6
        }

        Rectangle {
            width: parent.width
            height: 64
            radius: Theme.card.radius
            color: Theme.card.fill
            border.width: Theme.card.borderWidth
            border.color: Theme.card.borderColor

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

        ZendaExpandPanel {
            id: inputDropdown
            expanded: root.expandedSection === "input"
            contentHeight: sourcesColumn.implicitHeight + 20

            Column {
                id: sourcesColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                Repeater {
                    model: Audio.sources

                    delegate: ZendaListItem {
                        required property var modelData
                        width: sourcesColumn.width
                        visible: !modelData.isSink && !modelData.isStream && !!modelData.audio
                        height: visible ? implicitHeight : 0
                        selected: Audio.source?.id === modelData.id
                        leadingIcon: "󰍬"
                        text: Audio.getDisplayName(modelData)
                        onClicked: {
                            Audio.setAudioSource(modelData);
                            root.expandedSection = "";
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
