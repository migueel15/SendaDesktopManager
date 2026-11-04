import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.components.controls
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    ColumnLayout {
        id: column
        width: root.width
        ZendaGroup {
            ZendaRow {
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
