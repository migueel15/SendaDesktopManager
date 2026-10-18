import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.components
import qs.services

// Settings for Google Calendar and the weather location. Opened with
// `senda settings` or from the dashboard. Every change goes through the CLI.
SendaPanel {
    id: root
    name: "settings"

    padding: 16
    targetWidth: 560
    targetHeight: 560

    targetX: parent.width / 2 - root.width / 2
    targetY: 45

    // Calendar IDs currently checked in the list below.
    property var selectedCalendars: []

    function syncFields() {
        if (clientIdField.text === "") {
            clientIdField.text = SendaSettings.values.SENDA_GOOGLE_CLIENT_ID ?? "";
        }
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

    onVisibleChanged: {
        if (visible) {
            SendaSettings.refresh();
        }
    }

    Connections {
        target: SendaSettings

        function onValuesChanged() {
            root.syncFields();
        }

        function onCalendarsChanged() {
            root.syncCalendarSelection();
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Configuración"
                    color: Theme.colors.text
                    font.family: Theme.font.title.family
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
                SettingsButton {
                    label: "Cerrar"
                    onClicked: OverlayService.closeCurrentPanel()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: SendaSettings.notice !== ""
                text: SendaSettings.notice
                color: SendaSettings.noticeIsError ? Theme.colors.warning : Theme.colors.success
                font.family: Theme.font.overlay.family
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.colors.surfaceVariant
            }

            Text {
                text: "GOOGLE CALENDAR"
                color: Theme.colors.overlay
                font.family: Theme.font.overlay.family
                font.pixelSize: 11
                font.weight: Font.Bold
            }

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

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Theme.rounding.small
                    color: "transparent"

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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.topMargin: 6
                color: Theme.colors.surfaceVariant
            }

            Text {
                text: "CLIMA"
                color: Theme.colors.overlay
                font.family: Theme.font.overlay.family
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Text {
                Layout.fillWidth: true
                text: `Localidad: ${SendaSettings.values.SENDA_WEATHER_LOCATION || "sin elegir"}`
                color: Theme.colors.text
                font.family: Theme.font.base.family
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SettingsField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholder: "Busca tu localidad"
                    onAccepted: SendaSettings.searchPlaces(searchField.text)
                }
                SettingsButton {
                    label: "Buscar"
                    enabled: !SendaSettings.busy && searchField.text.trim().length >= 2
                    onClicked: SendaSettings.searchPlaces(searchField.text)
                }
            }

            Repeater {
                model: SendaSettings.places

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Theme.rounding.small
                    color: placeMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: [modelData.name, modelData.admin, modelData.country].filter(part => part).join(", ")
                        color: Theme.colors.text
                        font.family: Theme.font.base.family
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: placeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !SendaSettings.busy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SendaSettings.saveLocation(modelData)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.syncFields();
        root.syncCalendarSelection();
    }
}
