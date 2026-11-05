import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.components.controls
import qs.services

// Everything the bar and dashboard widgets show: calendar, weather and the
// bar controls. The calendar and weather pages are embedded without their
// own scrolling, so this page scrolls as one.
Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    component EmbeddedPage: Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.contentHeight : 0
        onLoaded: item.interactive = false
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        Text { text: "Calendario"; color: Theme.colors.primary; font: Theme.font.heading }
        EmbeddedPage { source: Qt.resolvedUrl("CalendarSettingsPage.qml") }

        Text { text: "Tiempo"; color: Theme.colors.primary; font: Theme.font.heading }
        EmbeddedPage { source: Qt.resolvedUrl("WeatherSettingsPage.qml") }

        Text { text: "Barra"; color: Theme.colors.primary; font: Theme.font.heading }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Spotify"
                modified: ZendaSettings.values.ZENDA_WIDGET_SPOTIFY === "false"
                onResetRequested: ZendaSettings.save({ ZENDA_WIDGET_SPOTIFY: "" }, "Widget de Spotify restablecido")
                description: "Muestra los controles de música en la barra."
                ZendaSwitch {
                    Accessible.name: "Habilitar widget de Spotify"
                    checkedValue: ZendaSettings.values.ZENDA_WIDGET_SPOTIFY !== "false"
                    enabled: !ZendaSettings.busy
                    onToggledValue: value => ZendaSettings.save({ ZENDA_WIDGET_SPOTIFY: String(value) }, "Widget de Spotify guardado")
                }
            }
            ZendaRow {
                label: "Discord"
                modified: ZendaSettings.values.ZENDA_WIDGET_DISCORD === "false"
                onResetRequested: ZendaSettings.save({ ZENDA_WIDGET_DISCORD: "" }, "Widget de Discord restablecido")
                description: "Muestra los controles de voz en la barra."
                ZendaSwitch {
                    Accessible.name: "Habilitar widget de Discord"
                    checkedValue: ZendaSettings.values.ZENDA_WIDGET_DISCORD !== "false"
                    enabled: !ZendaSettings.busy
                    onToggledValue: value => ZendaSettings.save({ ZENDA_WIDGET_DISCORD: String(value) }, "Widget de Discord guardado")
                }
            }
        }
    }
}
