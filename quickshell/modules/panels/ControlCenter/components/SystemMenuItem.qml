import QtQuick
import Quickshell
import QtQuick.Layouts

import qs.common
import qs.common.components.icons

Rectangle {
    id: menuItem

    property string icon: ""
    property string text: ""

    signal clicked

    width: parent.width
    height: 38
    radius: Theme.rounding.normal
    color: mouseArea.containsMouse ? Theme.colors.surfaceVariant : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: menuItem.text
            font: Theme.font.overlay
            color: Theme.colors.text
            elide: Text.ElideRight
        }

        IconSlot {
            icon: menuItem.icon
            iconColor: Theme.colors.overlay
            gapBefore: 8
            gapAfter: 0
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menuItem.clicked()
    }
}
