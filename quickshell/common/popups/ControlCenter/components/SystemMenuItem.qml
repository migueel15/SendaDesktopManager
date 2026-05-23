import QtQuick
import Quickshell
import QtQuick.Layouts

import qs.common

Rectangle {
    id: menuItem

    property string icon: ""
    property string text: ""
    property bool isHovered: mouseArea.containsMouse

    signal clicked()

    width: parent.width
    height: 40
    color: isHovered ? Theme.colors.surfaceVariant : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        spacing: 10

        Text {
            text: menuItem.icon
            font.pixelSize: 18
            color: Theme.colors.text
        }

        Text {
            text: menuItem.text
            font: Theme.font.base
            color: Theme.colors.text
            Layout.fillWidth: true
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
