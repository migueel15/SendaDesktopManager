import QtQuick
import QtQuick.Layouts

import qs.common
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
        SendaSettings.save(
            { SENDA_UI_FONT_SCALE: clamped === 100 ? "" : String(clamped) },
            "Tamaño de letra guardado"
        );
    }

    Component.onCompleted: SendaTheme.refresh()

    ColumnLayout {
        id: column
        width: root.width
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Tema"
                description: SendaTheme.lastError !== "" ? SendaTheme.lastError : "Colores y fondo de todo el escritorio."
            }
            Repeater {
                model: SendaTheme.themes.filter(theme => theme.valid)
                delegate: SettingsButton {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.name
                    primary: modelData.name === Theme.currentTheme
                    enabled: !SendaTheme.busy
                    onClicked: SendaTheme.apply(modelData.name)
                }
            }
        }
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Tamaño de la letra"
                description: "Escala toda la interfaz entre 80 y 150 %."
                SettingsSlider {
                    value: root.currentPercent
                    enabled: !SendaSettings.busy
                    onCommitted: value => root.changeTo(value)
                }
            }
        }
    }
}
