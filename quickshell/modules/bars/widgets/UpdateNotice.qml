import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Bar notice for a newer Senda release. It offers to update now or to close the
// notice until the next release.
RowLayout {
    id: root

    visible: SendaUpdate.noticeVisible
    spacing: 10

    Text {
        text: `Nueva versión ${SendaUpdate.latest} disponible`
        color: Theme.colors.text
        font.family: Theme.font.overlay.family
        font.pixelSize: Theme.scaled(11)
    }

    Rectangle {
        Layout.preferredHeight: 22
        Layout.preferredWidth: updateLabel.implicitWidth + 16
        radius: Theme.rounding.small
        color: updateMouse.containsMouse ? Theme.colors.primary : "transparent"
        border.width: 1
        border.color: Theme.colors.primary

        Text {
            id: updateLabel
            anchors.centerIn: parent
            text: "Actualizar"
            color: updateMouse.containsMouse ? Theme.colors.background : Theme.colors.primary
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            font.weight: Font.Bold
        }

        MouseArea {
            id: updateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SendaUpdate.install()
        }
    }

    Text {
        text: "×"
        color: Theme.colors.overlay
        font.family: Theme.font.title.family
        font.pixelSize: Theme.scaled(14)

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: SendaUpdate.dismiss()
        }
    }
}
