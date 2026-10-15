import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.common
import qs.common.components
import qs.common.components.icons
import qs.modules.panels.ControlCenter.components
import qs.services

SendaPanel {
    id: root
    name: "controlCenter"

    targetWidth: 500
    targetHeight: container.implicitHeight

    Rectangle {
        id: container
        anchors.fill: parent
        color: "transparent"
        implicitHeight: mainColumn.implicitHeight

        Column {
            id: mainColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 8

            UserCard {
                id: userCard
                onPowerMenuToggleRequested: systemMenu.toggle()
                onPowerMenuCloseRequested: systemMenu.close()
            }

            SystemMenu {
                id: systemMenu
                width: parent.width
            }

            RowLayout {
                width: parent.width
                spacing: 8

                WifiControl {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                }

                BluetoothControl {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                }
            }

            AudioControl {}

            DndControl {
                Layout.fillWidth: true
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onPressed: userCard.closeSystemMenu()
        }
    }

    component WifiControl: Item {
        id: wifiControl

        implicitWidth: 220
        implicitHeight: wifiColumn.implicitHeight
        property bool expanded: false
        property string passwordNetwork: ""

        Column {
            id: wifiColumn
            width: parent.width
            spacing: 6

            Rectangle {
                width: parent.width
                height: 92
                radius: Theme.rounding.normal
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
                            icon: Network.wifiEnabled ? (Network.wifiConnected ? "󰖩" : "󰖪") : "󰖪"
                            iconColor: Network.wifiEnabled ? Theme.colors.primary : Theme.colors.overlay
                            gapAfter: 8
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Wi-Fi"
                                color: Theme.colors.overlay
                                font: Theme.font.overlay
                            }

                            Text {
                                Layout.fillWidth: true
                                text: !Network.wifiEnabled ? "Desactivado" : Network.wifiConnected ? Network.wifiSsid : "Sin conexión"
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
                            color: Network.wifiEnabled ? Theme.colors.primary : Theme.colors.surfaceVariant

                            Rectangle {
                                width: 16
                                height: 16
                                y: 3
                                x: Network.wifiEnabled ? parent.width - width - 3 : 3
                                radius: Theme.rounding.full
                                color: Theme.colors.background
                                Behavior on x { NumberAnimation { duration: 120 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Network.toggleWifi()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            text: Network.wifiEnabled ? (Network.wifiConnected ? "Conectado" : "Seleccionar red") : "Activa Wi-Fi para buscar redes"
                            color: Network.wifiConnected ? Theme.colors.success : Theme.colors.overlay
                            font: Theme.font.overlay
                            elide: Text.ElideRight
                        }

                        IconSlot {
                            icon: wifiControl.expanded ? "" : ""
                            iconColor: Theme.colors.overlay
                            iconFont: Theme.font.icon
                            gapAfter: 0
                            interactive: true
                            onClicked: wifiControl.toggleExpanded()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: wifiControl.toggleExpanded()
                }
            }

            Rectangle {
                width: parent.width
                height: wifiControl.expanded ? networksColumn.implicitHeight + 20 : 0
                visible: height > 0
                radius: Theme.rounding.normal
                color: Theme.colors.surface
                border.width: 1
                border.color: Theme.colors.surfaceVariant
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                }

                Column {
                    id: networksColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 3

                    RowLayout {
                        width: networksColumn.width
                        height: 28

                        Text {
                            Layout.fillWidth: true
                            text: "REDES DISPONIBLES"
                            color: Theme.colors.overlay
                            font: Qt.font({
                                family: Theme.font.overlay.family,
                                pixelSize: Theme.font.overlay.pixelSize,
                                weight: Font.Bold
                            })
                        }

                        Text {
                            text: Network.wifiScanning ? "…" : "↻"
                            color: Theme.colors.primary
                            font: Theme.font.title

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Network.refreshWifi(true)
                            }
                        }
                    }

                    Text {
                        width: networksColumn.width
                        height: Network.wifiEnabled && Network.wifiNetworks.length === 0 ? 34 : 0
                        visible: height > 0
                        text: Network.wifiScanning ? "Buscando redes…" : "No se encontraron redes"
                        color: Theme.colors.overlay
                        font: Theme.font.overlay
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        width: networksColumn.width
                        height: !Network.wifiEnabled ? 34 : 0
                        visible: height > 0
                        text: "Activa Wi-Fi para buscar redes"
                        color: Theme.colors.overlay
                        font: Theme.font.overlay
                        verticalAlignment: Text.AlignVCenter
                    }

                    Repeater {
                        model: Network.wifiNetworks

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool needsPassword: Network.wifiNeedsPasswordFor === modelData.ssid
                            readonly property bool connected: modelData.connected

                            width: networksColumn.width
                            height: needsPassword ? 78 : 40
                            radius: Theme.rounding.normal
                            color: connected || networkMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                spacing: 2

                                RowLayout {
                                    width: parent.width
                                    height: 38
                                    spacing: 8

                                    Text {
                                        text: modelData.security && modelData.security !== "--" ? "" : ""
                                        color: Theme.colors.overlay
                                        font: Theme.font.overlay
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.ssid
                                        color: connected ? Theme.colors.primary : Theme.colors.text
                                        font: Theme.font.overlay
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.signal + "%"
                                        color: Theme.colors.overlay
                                        font: Theme.font.overlay
                                    }

                                    Text {
                                        text: connected ? "✓" : ""
                                        color: Theme.colors.success
                                        font: Theme.font.overlay
                                    }
                                }

                                RowLayout {
                                    width: parent.width
                                    height: 34
                                    visible: needsPassword
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: Theme.rounding.normal
                                        color: Theme.colors.background

                                        TextInput {
                                            id: passwordInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 9
                                            anchors.rightMargin: 9
                                            verticalAlignment: TextInput.AlignVCenter
                                            color: Theme.colors.text
                                            font: Theme.font.overlay
                                            echoMode: TextInput.Password
                                            clip: true
                                            enabled: !Network.wifiBusy
                                            onAccepted: connectButton.connect()
                                        }
                                    }

                                    Rectangle {
                                        id: connectButton
                                        Layout.preferredWidth: 78
                                        Layout.fillHeight: true
                                        radius: Theme.rounding.normal
                                        color: Theme.colors.primary

                                        function connect() {
                                            if (!passwordInput.text || Network.wifiBusy) return;
                                            Network.connectWifi(modelData.ssid, passwordInput.text);
                                            passwordInput.text = "";
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Network.wifiBusy ? "…" : "Conectar"
                                            color: Theme.colors.background
                                            font: Qt.font({
                                                family: Theme.font.overlay.family,
                                                pixelSize: Theme.font.overlay.pixelSize,
                                                weight: Font.Bold
                                            })
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !Network.wifiBusy
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: connectButton.connect()
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: networkMouse
                                anchors.fill: parent
                                z: -1
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !needsPassword && !connected && !Network.wifiBusy
                                onClicked: {
                                    wifiControl.passwordNetwork = modelData.ssid;
                                    Network.connectWifi(modelData.ssid);
                                }
                            }
                        }
                    }

                    Text {
                        width: networksColumn.width
                        height: Network.wifiError ? 34 : 0
                        visible: height > 0
                        text: Network.wifiError
                        color: Theme.colors.error
                        font: Theme.font.overlay
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        function toggleExpanded() {
            wifiControl.expanded = !wifiControl.expanded;
            if (wifiControl.expanded && Network.wifiEnabled) Network.refreshWifi(true);
        }
    }

    component DndControl: Item {
        id: dndControl

        width: parent.width
        implicitHeight: 62
        property bool dndEnabled: false

        Component.onCompleted: dndControl.dndEnabled = Notifications.dndEnabled

        Connections {
            target: Notifications

            function onDndChanged(enabled) {
                dndControl.dndEnabled = enabled;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.normal
            color: dndControl.dndEnabled ? "#29283a" : Theme.colors.surface
            border.width: 1
            border.color: dndControl.dndEnabled ? Theme.colors.primary : Theme.colors.surfaceVariant

            RowLayout {
                id: dndRow
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0

                Item {
                    id: dndIcon
                    width: 24
                    height: 24
                    Layout.rightMargin: 8

                    IconSlot {
                        anchors.fill: parent
                        icon: "󰂚"
                        iconColor: dndControl.dndEnabled ? Theme.colors.primary : Theme.colors.overlay
                        gapAfter: 0
                    }

                    Rectangle {
                        width: 21
                        height: 2
                        anchors.centerIn: parent
                        rotation: -45
                        color: Theme.colors.primary
                        visible: dndControl.dndEnabled
                    }
                }

                Column {
                    id: dndText
                    Layout.fillWidth: true
                    Layout.rightMargin: 8
                    spacing: 1

                    Text {
                        width: parent.width
                        text: "No molestar"
                        color: Theme.colors.text
                        font: Qt.font({
                            family: Theme.font.overlay.family,
                            pixelSize: Theme.font.overlay.pixelSize,
                            weight: Font.Bold
                        })
                    }

                    Text {
                        width: parent.width
                        text: dndControl.dndEnabled ? "Notificaciones silenciadas" : "Notificaciones activas"
                        color: Theme.colors.overlay
                        font: Theme.font.overlay
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: dndToggle
                    Layout.leftMargin: 8
                    width: 42
                    height: 24
                    radius: Theme.rounding.full
                    color: dndControl.dndEnabled ? Theme.colors.primary : Theme.colors.surfaceVariant

                    Rectangle {
                        width: 18
                        height: 18
                        y: 3
                        x: dndControl.dndEnabled ? parent.width - width - 3 : 3
                        radius: Theme.rounding.full
                        color: Theme.colors.background
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dndControl.toggle()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: dndControl.toggle()
            }
        }

        function toggle() {
            Notifications.toggleDnd();
        }
    }
}
