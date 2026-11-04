import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.components.controls
import qs.common.components.icons
import qs.services

Item {
    id: root

    implicitWidth: 220
    implicitHeight: column.implicitHeight
    property bool devicesExpanded: false
    property bool panelOpen: false
    readonly property bool discoveryRequested: root.panelOpen && root.devicesExpanded

    onDiscoveryRequestedChanged: Bluetooth.requestDiscovery(root, root.discoveryRequested)
    Component.onDestruction: Bluetooth.requestDiscovery(root, false)

    Column {
        id: column
        width: parent.width
        // Selectors attach directly under their card.
        spacing: 0

        Rectangle {
            width: parent.width
            height: 92
            radius: Theme.card.radius
            color: Theme.card.fill
            border.width: Theme.card.borderWidth
            border.color: Theme.card.borderColor

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

                    ZendaSwitch {
                        Layout.leftMargin: 8
                        checkedValue: Bluetooth.enabled
                        onToggledValue: Bluetooth.toggleEnabled()
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

        ZendaExpandPanel {
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
                    visible: Bluetooth.enabled
                    height: visible ? 24 : 0
                    text: Bluetooth.discovering ? "Buscando dispositivos…" : "Dispositivos disponibles"
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: devicesColumn.width
                    height: !Bluetooth.available || Bluetooth.enabled && Bluetooth.namedDevices.length === 0 ? 36 : 0
                    visible: height > 0
                    text: !Bluetooth.available ? "Bluetooth no disponible" : "No hay dispositivos con nombre"
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: Bluetooth.namedDevices

                    delegate: ZendaListItem {
                        required property var modelData
                        width: devicesColumn.width
                        interactive: !Bluetooth.pairing
                        selected: Bluetooth.activeDevice?.address === modelData.address
                        leadingIcon: modelData.icon?.includes("headset") || modelData.icon?.includes("audio") ? "󰋋" : "󰂯"
                        text: Bluetooth.getDisplayName(modelData)
                        trailingIcon: ""
                        trailingText: modelData.pairing || Bluetooth.pairing && Bluetooth.pairingDevice === modelData ? "Emparejando…" : modelData.connected ? (Bluetooth.getBatteryLabel(modelData) || "Conectado") : (modelData.paired ? "Desconectado" : "Sin emparejar")
                        trailingColor: modelData.connected ? Theme.colors.success : Theme.colors.overlay
                        onClicked: {
                            const wasPaired = modelData.paired;
                            if (modelData.connected) Bluetooth.disconnectDevice(modelData);
                            else Bluetooth.connectDevice(modelData);
                            if (wasPaired) root.devicesExpanded = false;
                        }
                    }
                }

                Text {
                    width: devicesColumn.width
                    visible: Bluetooth.pairingError !== ""
                    height: visible ? implicitHeight : 0
                    text: Bluetooth.pairingError
                    textFormat: Text.PlainText
                    color: Theme.colors.error
                    font: Theme.font.overlay
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
