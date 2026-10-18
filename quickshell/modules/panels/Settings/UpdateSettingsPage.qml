import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Update settings: the installed version, the latest release, and the update.
Flickable {
    id: root

    contentHeight: column.implicitHeight
    clip: true

    ColumnLayout {
        id: column
        width: root.width
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: `Versión instalada: ${SendaUpdate.current || "sin comprobar"}`
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(13)
        }

        Text {
            Layout.fillWidth: true
            text: SendaUpdate.latest !== ""
                ? (SendaUpdate.available ? `Hay una versión nueva: ${SendaUpdate.latest}` : "Tienes la última versión")
                : "Aún no se ha consultado la última versión"
            color: SendaUpdate.available ? Theme.colors.success : Theme.colors.overlay
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(13)
        }

        Text {
            Layout.fillWidth: true
            visible: SendaUpdate.message !== ""
            text: SendaUpdate.message
            color: Theme.colors.warning
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: SendaUpdate.current === "dev"
            text: "Esta es una compilación de desarrollo y no se puede actualizar desde aquí."
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingsButton {
                label: "Comprobar ahora"
                onClicked: SendaUpdate.check()
            }

            SettingsButton {
                label: "Actualizar ahora"
                primary: true
                enabled: SendaUpdate.available
                onClicked: SendaUpdate.install()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SendaUpdate.available
            text: "Al actualizar, Senda descarga la versión nueva, la verifica y reinicia el shell."
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WordWrap
        }
    }
}
