import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.components.icons
import qs.services

Item {
    id: root

    implicitWidth: 220
    implicitHeight: column.implicitHeight
    property bool devicesExpanded: false

    Column {
        id: column
        width: parent.width
        // Selectors attach directly under their card.
        spacing: 0

        Rectangle {
            width: parent.width
            height: 92
            radius: Theme.rounding.normal
            // Square while its selector is attached below.
            bottomLeftRadius: devicesDropdown.attached ? 0 : Theme.rounding.normal
            bottomRightRadius: devicesDropdown.attached ? 0 : Theme.rounding.normal
            color: Theme.colors.surface
            border.width: 1
            border.color: Theme.colors.surfaceVariant

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    IconSlot {
                        icon: Bluetooth.icon
                        iconColor: Bluetooth.enabled ? Theme.colors.primary : Theme.colors.overlay
                        gapAfter: 8
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Bluetooth"
                            color: Theme.colors.overlay
                            font: Theme.font.overlay
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Bluetooth.activeDevice ? Bluetooth.getDisplayName(Bluetooth.activeDevice) : (Bluetooth.enabled ? "Sin dispositivo" : "Desactivado")
                            color: Theme.colors.text
                            font: Theme.font.overlay
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.leftMargin: 8
                        width: 38
                        height: 22
                        radius: Theme.rounding.full
                        color: Bluetooth.enabled ? Theme.colors.primary : Theme.colors.surfaceVariant

                        Rectangle {
                            width: 16
                            height: 16
                            y: 3
                            x: Bluetooth.enabled ? parent.width - width - 3 : 3
                            radius: Theme.rounding.full
                            color: Theme.colors.background

                            Behavior on x { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Bluetooth.toggleEnabled()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: !Bluetooth.available ? "Adaptador no disponible" : Bluetooth.activeDevice ? `Conectado${Bluetooth.getBatteryLabel(Bluetooth.activeDevice) ? ` · ${Bluetooth.getBatteryLabel(Bluetooth.activeDevice)}` : ""}` : "Gestionar dispositivos"
                        color: Bluetooth.activeDevice ? Theme.colors.success : Theme.colors.overlay
                        font: Theme.font.overlay
                        elide: Text.ElideRight
                    }

                    IconSlot {
                        icon: root.devicesExpanded ? "" : ""
                        iconColor: Theme.colors.overlay
                        iconFont: Theme.font.icon
                        gapBefore: 0
                        gapAfter: 0
                        interactive: true
                        onClicked: root.devicesExpanded = !root.devicesExpanded
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.devicesExpanded = !root.devicesExpanded
            }
        }

        DropdownCard {
            id: devicesDropdown
            expanded: root.devicesExpanded
            contentHeight: devicesColumn.implicitHeight + 20

            Column {
                id: devicesColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                Text {
                    width: devicesColumn.width
                    height: !Bluetooth.available || Bluetooth.enabled && Bluetooth.devices.length === 0 ? 36 : 0
                    visible: height > 0
                    text: !Bluetooth.available ? "Bluetooth no disponible" : "No hay dispositivos guardados"
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: Bluetooth.devices

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool activeDevice: Bluetooth.activeDevice?.address === modelData.address

                        width: devicesColumn.width
                        height: 38
                        radius: Theme.rounding.normal
                        color: activeDevice || deviceMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: Bluetooth.getDisplayName(modelData)
                                color: activeDevice ? Theme.colors.primary : Theme.colors.text
                                font: Theme.font.overlay
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.connected ? (Bluetooth.getBatteryLabel(modelData) || "Conectado") : "Desconectado"
                                color: modelData.connected ? Theme.colors.success : Theme.colors.overlay
                                font: Theme.font.overlay
                            }
                        }

                        MouseArea {
                            id: deviceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) Bluetooth.disconnectDevice(modelData);
                                else Bluetooth.connectDevice(modelData);
                                root.devicesExpanded = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
