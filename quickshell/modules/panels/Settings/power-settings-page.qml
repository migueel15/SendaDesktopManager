pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.components.controls
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    Connections {
        target: ZendaHyprlandSettings
        function onValuesChanged() {
            idleField.text = String(ZendaHyprlandSettings.values.idleSeconds);
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        ZendaGroup {
            visible: Battery.isLaptop
            ZendaRow {
                separator: false
                label: "Aviso de batería baja"
                description: "Avisa una vez al bajar de este nivel, sin cargador. Vuelve a avisar tras recuperar carga."
                modified: Battery.warningPercent !== Battery.defaultWarningPercent
                onResetRequested: ZendaSettings.save({ ZENDA_BATTERY_WARNING: "" }, "Aviso de batería restablecido")
                ZendaSlider {
                    from: 5
                    to: 95
                    stepSize: 5
                    value: Battery.warningPercent
                    enabled: ZendaSettings.configLoaded
                    onCommitted: value => ZendaSettings.save({ ZENDA_BATTERY_WARNING: String(value) }, "Aviso de batería guardado")
                }
            }
        }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Tiempo de inactividad"
                modified: ZendaHyprlandSettings.loaded && ZendaHyprlandSettings.values.idleSeconds !== 600
                onResetRequested: { idleField.text = "600"; ZendaHyprlandSettings.save("--idle-seconds", 600); }
                description: "Segundos, de 0 a 86400. 0 desactiva el bloqueo automático."
                ZendaSavedMark { flag: "--idle-seconds" }
                ZendaField {
                    id: idleField
                    Layout.preferredWidth: 100
                    enabled: ZendaHyprlandSettings.loaded
                    text: ZendaHyprlandSettings.loaded ? String(ZendaHyprlandSettings.values.idleSeconds) : ""
                    placeholder: "Segundos"
                    onCommitted: if (!ZendaHyprlandSettings.save("--idle-seconds", text.trim())) text = String(ZendaHyprlandSettings.values.idleSeconds)
                }
            }
        }
    }
}
