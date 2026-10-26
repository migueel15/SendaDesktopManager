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

        SettingsGroup {

            SettingsRow {
                separator: false
                label: SendaUpdate.available
                    ? `${SendaUpdate.current} → ${SendaUpdate.latest}`
                    : `Versión ${SendaUpdate.current || "sin comprobar"}`
                description: SendaUpdate.message
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
}
