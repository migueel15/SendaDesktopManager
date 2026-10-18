import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Small bar notice for a newer Senda release. Clicking it opens the update
// section of the settings; the × hides it until the next release.
RowLayout {
    id: root

    property string screenName: ""

    visible: SendaUpdate.noticeVisible
    spacing: 6

    Rectangle {
        Layout.preferredHeight: 22
        Layout.preferredWidth: noticeLabel.implicitWidth + 16
        radius: Theme.rounding.small
        color: noticeMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"
        border.width: 1
        border.color: Theme.colors.primary

        Text {
            id: noticeLabel
            anchors.centerIn: parent
            text: `${SendaUpdate.latest}  ${String.fromCodePoint(0xF0AA)}`
            color: Theme.colors.primary
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
        }

        MouseArea {
            id: noticeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SendaUpdate.openSettings(root.screenName)
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
