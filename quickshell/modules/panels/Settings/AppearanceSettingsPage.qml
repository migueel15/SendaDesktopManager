import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Appearance settings: the size of the interface text. 100% is the default.
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

    ColumnLayout {
        id: column
        width: root.width
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Tamaño de la letra"
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(13)
        }

        Text {
            Layout.fillWidth: true
            text: "Aumenta o reduce el texto de la interfaz. Afecta al dashboard, al centro de control y a los paneles."
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingsButton {
                label: "−"
                enabled: !SendaSettings.busy && root.currentPercent > root.minPercent
                onClicked: root.changeTo(root.currentPercent - root.stepPercent)
            }

            Text {
                Layout.preferredWidth: 70
                horizontalAlignment: Text.AlignHCenter
                text: `${root.currentPercent}%`
                color: Theme.colors.text
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(16)
                font.weight: Font.Bold
            }

            SettingsButton {
                label: "+"
                enabled: !SendaSettings.busy && root.currentPercent < root.maxPercent
                onClicked: root.changeTo(root.currentPercent + root.stepPercent)
            }

            Item {
                Layout.fillWidth: true
            }

            SettingsButton {
                label: "Restablecer"
                enabled: !SendaSettings.busy && root.currentPercent !== 100
                onClicked: root.changeTo(100)
            }
        }

        Text {
            Layout.fillWidth: true
            text: `Rango permitido: ${root.minPercent}% a ${root.maxPercent}%.`
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
        }
    }
}
