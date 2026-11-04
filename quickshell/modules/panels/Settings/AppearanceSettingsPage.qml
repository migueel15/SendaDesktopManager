import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.components.controls
import qs.services

// Appearance settings: the theme and the size of the interface text.
Flickable {
    id: root

    readonly property int minPercent: 80
    readonly property int maxPercent: 150
    readonly property int stepPercent: 10
    readonly property int currentPercent: Math.round(Theme.fontScale * 100)

    contentHeight: column.implicitHeight
    clip: true

    function changeTo(percent) {
        const clamped = Math.max(root.minPercent, Math.min(root.maxPercent, percent));
        // 100% is stored as no value, so the file keeps only deliberate changes.
        ZendaSettings.save(
            { ZENDA_UI_FONT_SCALE: clamped === 100 ? "" : String(clamped) },
            "Tamaño de letra guardado"
        );
    }

    Component.onCompleted: ZendaTheme.refresh()

    ColumnLayout {
        id: column
        width: root.width
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Tema"
                modified: Theme.currentTheme !== "zenda-ice"
                onResetRequested: ZendaTheme.apply("zenda-ice")
                description: ZendaTheme.lastError !== "" ? ZendaTheme.lastError : "Colores y fondo de todo el escritorio."
            }
            Repeater {
                model: ZendaTheme.themes.filter(theme => theme.valid)
                delegate: ZendaButton {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.name
                    primary: modelData.name === Theme.currentTheme
                    enabled: !ZendaTheme.busy
                    onClicked: ZendaTheme.apply(modelData.name)
                }
            }
        }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Tamaño de la letra"
                modified: root.currentPercent !== 100
                onResetRequested: root.changeTo(100)
                description: "Escala toda la interfaz entre 80 y 150 %."
                ZendaSlider {
                    value: root.currentPercent
                    enabled: !ZendaSettings.busy
                    onCommitted: value => root.changeTo(value)
                }
            }
        }
    }
}
