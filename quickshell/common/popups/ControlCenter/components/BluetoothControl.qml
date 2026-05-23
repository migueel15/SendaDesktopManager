import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import qs.common
import qs.common.services

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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: Bluetooth.icon
                        color: Bluetooth.enabled ? Theme.colors.primary : Theme.colors.text
                        font: Theme.font.base
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Bluetooth.activeDevice ? Bluetooth.getDisplayName(Bluetooth.activeDevice) : "Bluetooth"
                        color: Theme.colors.text
                        font: Theme.font.base
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Bluetooth.activeDevice ? Bluetooth.getBatteryLabel(Bluetooth.activeDevice) : ""
                        color: Theme.colors.primary
                        font: Theme.font.base
                        visible: text.length > 0
                        Layout.alignment: Qt.AlignRight
                    }
                }

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

                Text {
                    width: devicesColumn.width
                    height: Bluetooth.available ? 0 : 35
                    visible: !Bluetooth.available
                    text: "Bluetooth no disponible"
                    color: Theme.colors.text
                    font: Theme.font.base
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: devicesColumn.width
                    height: Bluetooth.available && Bluetooth.devices.length === 0 ? 35 : 0
                    visible: Bluetooth.available && Bluetooth.devices.length === 0
                    text: "No hay dispositivos"
                    color: Theme.colors.text
                    font: Theme.font.base
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: Bluetooth.devices

                    delegate: Rectangle {
                        required property var modelData

                        width: devicesColumn.width
                        height: 35
                        radius: 6
                        color: deviceMouseArea.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                        property bool isActive: Bluetooth.activeDevice?.address === modelData.address

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: Bluetooth.getDisplayName(modelData)
                                color: parent.isActive ? Theme.colors.primary : Theme.colors.text
                                font: Theme.font.base
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.connected ? (() => {
                                        const batteryLabel = Bluetooth.getBatteryLabel(modelData);
                                        return batteryLabel ? `Conectado · ${batteryLabel}` : "Conectado";
                                    })() : ""
                                color: Theme.colors.primary
                                font: Theme.font.base
                                visible: modelData.connected
                            }
                        }

                        MouseArea {
                            id: deviceMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (modelData.connected) {
                                    Bluetooth.disconnectDevice(modelData);
                                } else {
                                    Bluetooth.connectDevice(modelData);
                                }
                                root.devicesExpanded = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
