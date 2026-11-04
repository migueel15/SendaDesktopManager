pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

Flickable {
    id: root
    readonly property bool retainWhenHidden: clientIdField.text !== "" || clientSecretField.text !== ""
    // Selection follows confirmed configuration, including after a failed save.
    readonly property var selectedCalendars: {
        const configured = (ZendaSettings.values.ZENDA_GOOGLE_CALENDARS ?? "")
            .split(",").map(id => id.trim()).filter(id => id !== "");
        return configured.length > 0 ? configured
            : ZendaSettings.calendars.filter(calendar => calendar.selected).map(calendar => calendar.id);
    }
    property bool showOwnClient: false
    contentHeight: column.implicitHeight
    clip: true

    function openOwnClient() {
        clientIdField.text = "";
        clientSecretField.text = "";
        root.showOwnClient = true;
    }
    function confirmClient() {
        if (ZendaSettings.busy || clientIdField.text.trim() === "") return;
        ZendaSettings.saveGoogleClient(clientIdField.text, clientSecretField.text);
        clientSecretField.text = "";
    }
    function toggleCalendar(id) {
        const next = root.selectedCalendars.includes(id)
            ? root.selectedCalendars.filter(item => item !== id)
            : [...root.selectedCalendars, id];
        if (next.length === 0) return;
        ZendaSettings.saveCalendars(next);
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Cuenta de Google"
                description: ZendaSettings.connected ? "Cuenta conectada" : "Cuenta no conectada"
                SettingsButton {
                    label: ZendaSettings.connected ? "Desconectar" : "Conectar con Google"
                    primary: !ZendaSettings.connected
                    enabled: !ZendaSettings.busy
                    onClicked: ZendaSettings.connected ? ZendaSettings.disconnectGoogle() : ZendaSettings.connectGoogle()
                }
            }
            SettingsRow {
                visible: !root.showOwnClient
                label: "Cliente OAuth propio"
                description: "Opcional si tu versión incluye las credenciales de Zenda."
                SettingsButton {
                    label: "Crear credenciales"
                    onClicked: root.openOwnClient()
                }
            }
            SettingsRow {
                visible: root.showOwnClient
                label: "ID de cliente"
                description: "Cliente OAuth de escritorio. ID y secreto se guardan juntos."
                SettingsField {
                    id: clientIdField
                    Layout.preferredWidth: 220
                    Layout.fillWidth: true
                    enabled: !ZendaSettings.busy
                    placeholder: "ID de cliente"
                    onAccepted: clientSecretField.focusInput()
                }
            }
            SettingsRow {
                visible: root.showOwnClient
                label: "Secreto del cliente"
                description: ZendaSettings.secretConfigured ? "Ya hay un secreto guardado; déjalo vacío para conservarlo." : "El secreto no se vuelve a mostrar."
                SettingsField {
                    id: clientSecretField
                    Layout.preferredWidth: 220
                    Layout.fillWidth: true
                    enabled: !ZendaSettings.busy
                    secret: true
                    placeholder: "Secreto del cliente"
                    onAccepted: root.confirmClient()
                }
            }
            SettingsButton {
                visible: root.showOwnClient
                Layout.alignment: Qt.AlignRight
                label: "Guardar credenciales"
                primary: true
                enabled: !ZendaSettings.busy && clientIdField.text.trim() !== ""
                onClicked: root.confirmClient()
            }
        }
        SettingsGroup {
            visible: ZendaSettings.connected && ZendaSettings.calendars.length > 0
            SettingsRow {
                separator: false
                label: "Calendarios a mostrar"
                description: "Cada cambio se guarda al instante. Debe quedar al menos un calendario seleccionado."
            }
            Repeater {
                model: ZendaSettings.connected ? ZendaSettings.calendars : []
                delegate: SettingsRow {
                    searchable: false
                    id: calendarRow
                    required property var modelData
                    label: modelData.summary || modelData.id
                    SettingsSwitch {
                        checkedValue: root.selectedCalendars.includes(calendarRow.modelData.id)
                        enabled: !ZendaSettings.busy && (!checkedValue || root.selectedCalendars.length > 1)
                        Accessible.name: calendarRow.label
                        onToggledValue: root.toggleCalendar(calendarRow.modelData.id)
                    }
                }
            }
        }
    }
}
