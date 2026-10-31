import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    ColumnLayout {
        id: column
        width: root.width
        SettingsGroup {
            SettingsRow {
                label: "Spotify"
                modified: SendaSettings.values.SENDA_WIDGET_SPOTIFY === "false"
                onResetRequested: SendaSettings.save({ SENDA_WIDGET_SPOTIFY: "" }, "Widget de Spotify restablecido")
                description: "Muestra los controles de música en la barra."
                SettingsSwitch {
                    Accessible.name: "Habilitar widget de Spotify"
                    checkedValue: SendaSettings.values.SENDA_WIDGET_SPOTIFY !== "false"
                    enabled: !SendaSettings.busy
                    onToggledValue: value => SendaSettings.save({ SENDA_WIDGET_SPOTIFY: String(value) }, "Widget de Spotify guardado")
                }
            }
            SettingsRow {
                label: "Discord"
                modified: SendaSettings.values.SENDA_WIDGET_DISCORD === "false"
                onResetRequested: SendaSettings.save({ SENDA_WIDGET_DISCORD: "" }, "Widget de Discord restablecido")
                description: "Muestra los controles de voz en la barra."
                SettingsSwitch {
                    Accessible.name: "Habilitar widget de Discord"
                    checkedValue: SendaSettings.values.SENDA_WIDGET_DISCORD !== "false"
                    enabled: !SendaSettings.busy
                    onToggledValue: value => SendaSettings.save({ SENDA_WIDGET_DISCORD: String(value) }, "Widget de Discord guardado")
                }
            }
        }
    }
}
