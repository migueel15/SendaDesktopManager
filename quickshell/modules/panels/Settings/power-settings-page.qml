pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    Connections {
        target: SendaHyprlandSettings
        function onValuesChanged() {
            idleField.text = String(SendaHyprlandSettings.values.idleSeconds);
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        SettingsGroup {
            visible: Battery.isLaptop
            SettingsRow {
                separator: false
                label: "Aviso de batería baja"
                description: "Avisa una vez al bajar de este nivel, sin cargador. Vuelve a avisar tras recuperar carga."
                modified: Battery.warningPercent !== Battery.defaultWarningPercent
                onResetRequested: SendaSettings.save({ SENDA_BATTERY_WARNING: "" }, "Aviso de batería restablecido")
                SettingsSlider {
                    from: 5
                    to: 95
                    stepSize: 5
                    value: Battery.warningPercent
                    enabled: SendaSettings.configLoaded
                    onCommitted: value => SendaSettings.save({ SENDA_BATTERY_WARNING: String(value) }, "Aviso de batería guardado")
                }
            }
        }
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Tiempo de inactividad"
                modified: SendaHyprlandSettings.loaded && SendaHyprlandSettings.values.idleSeconds !== 600
                onResetRequested: { idleField.text = "600"; SendaHyprlandSettings.save("--idle-seconds", 600); }
                description: "Segundos, de 0 a 86400. 0 desactiva el bloqueo automático."
                SettingsSavedMark { flag: "--idle-seconds" }
                SettingsField {
                    id: idleField
                    Layout.preferredWidth: 100
                    enabled: SendaHyprlandSettings.loaded
                    text: SendaHyprlandSettings.loaded ? String(SendaHyprlandSettings.values.idleSeconds) : ""
                    placeholder: "Segundos"
                    onCommitted: if (!SendaHyprlandSettings.save("--idle-seconds", text.trim())) text = String(SendaHyprlandSettings.values.idleSeconds)
                }
            }
        }
    }
}
