import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Google Calendar settings: the connection, the OAuth client and the calendars
// to show.
Flickable {
    id: root

    // Calendar IDs currently checked in the list below.
    property var selectedCalendars: []

    // The own-client fields stay hidden until the user asks for them.
    property bool showOwnClient: false

    contentHeight: column.implicitHeight
    clip: true

    function openOwnClient() {
        clientIdField.text = "";
        clientSecretField.text = "";
        root.showOwnClient = true;
    }

    function syncCalendarSelection() {
        const configured = (SendaSettings.values.SENDA_GOOGLE_CALENDARS ?? "")
            .split(",")
            .map(id => id.trim())
            .filter(id => id !== "");
        root.selectedCalendars = configured.length > 0
            ? configured
            : SendaSettings.calendars.filter(calendar => calendar.selected).map(calendar => calendar.id);
    }

    function toggleCalendar(id) {
        if (root.selectedCalendars.includes(id)) {
            root.selectedCalendars = root.selectedCalendars.filter(item => item !== id);
        } else {
            root.selectedCalendars = [...root.selectedCalendars, id];
        }
    }

    Connections {
        target: SendaSettings

        function onCalendarsChanged() {
            root.syncCalendarSelection();
        }
    }

    Component.onCompleted: root.syncCalendarSelection()

    ColumnLayout {
        id: column
        width: root.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: SendaSettings.connected ? "Cuenta conectada" : "Cuenta no conectada"
                color: SendaSettings.connected ? Theme.colors.success : Theme.colors.overlay
                font.family: Theme.font.base.family
                font.pixelSize: 13
            }
            SettingsButton {
                label: SendaSettings.connected ? "Desconectar" : "Conectar con Google"
                primary: !SendaSettings.connected
                enabled: !SendaSettings.busy
                onClicked: SendaSettings.connected ? SendaSettings.disconnectGoogle() : SendaSettings.connectGoogle()
            }
        }

        // Own OAuth client. Hidden by default; the button opens two empty fields.
        SettingsButton {
            visible: !root.showOwnClient
            label: "Crear mis propias credenciales"
            onClicked: root.openOwnClient()
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showOwnClient
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Usa el ID y el secreto de tu cliente OAuth de escritorio. El secreto no se vuelve a mostrar."
                color: Theme.colors.overlay
                font.family: Theme.font.overlay.family
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            SettingsField {
                id: clientIdField
                Layout.fillWidth: true
                placeholder: "ID de cliente"
                onAccepted: clientSecretField.forceActiveFocus()
            }

            SettingsField {
                id: clientSecretField
                Layout.fillWidth: true
                secret: true
                placeholder: SendaSettings.secretConfigured ? "Secreto guardado; escribe uno nuevo para cambiarlo" : "Secreto del cliente"
            }

            SettingsButton {
                label: "Guardar credenciales"
                primary: true
                enabled: !SendaSettings.busy && clientIdField.text.trim() !== ""
                onClicked: {
                    SendaSettings.saveGoogleClient(clientIdField.text, clientSecretField.text);
                    clientSecretField.text = "";
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SendaSettings.connected && SendaSettings.calendars.length > 0
            text: "Calendarios a mostrar"
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: 13
        }

        Repeater {
            model: SendaSettings.connected ? SendaSettings.calendars : []

            delegate: Item {
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 28

                RowLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: root.selectedCalendars.includes(modelData.id) ? "󰄲" : "󰄱"
                        color: root.selectedCalendars.includes(modelData.id) ? Theme.colors.primary : Theme.colors.overlay
                        font.family: Theme.font.title.family
                        font.pixelSize: 16
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.summary || modelData.id
                        color: Theme.colors.text
                        font.family: Theme.font.base.family
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleCalendar(modelData.id)
                }
            }
        }

        SettingsButton {
            visible: SendaSettings.connected && SendaSettings.calendars.length > 0
            label: "Guardar calendarios"
            primary: true
            enabled: !SendaSettings.busy && root.selectedCalendars.length > 0
            onClicked: SendaSettings.saveCalendars(root.selectedCalendars)
        }
    }
}
