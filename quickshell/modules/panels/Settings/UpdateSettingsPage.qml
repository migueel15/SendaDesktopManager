import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Update settings: the installed version, the newer one when there is one, and
// the buttons to check again or update.
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
            text: SendaUpdate.available
                ? `${SendaUpdate.current} → ${SendaUpdate.latest}`
                : `Versión ${SendaUpdate.current || "sin comprobar"}`
            color: SendaUpdate.available ? Theme.colors.success : Theme.colors.text
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingsButton {
                label: "Comprobar"
                enabled: !SendaUpdate.busy
                onClicked: SendaUpdate.check()
            }

            SettingsButton {
                label: "Actualizar"
                primary: true
                enabled: SendaUpdate.available
                onClicked: SendaUpdate.install()
            }
        }
    }
}
