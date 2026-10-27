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
