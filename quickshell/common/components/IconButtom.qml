import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

import qs.common

Rectangle {
    id: root

    property string icon: ""
    property bool isHovered: mouseArea.containsMouse
    property int animationDuration: 150
    property var command: []
    property var onClick: () => {}

    implicitWidth: 40
    implicitHeight: 40
    radius: 100
    color: isHovered ? Theme.colors.surfaceVariant : Theme.colors.surface

    Behavior on color {
        ColorAnimation {
            duration: root.animationDuration
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.command.length > 0) {
                itemProcess.running = true;
            }
            root.onClick();
        }
    }

    Process {
        id: itemProcess
        running: false
        command: root.command
    }

    Text {
        id: textArea

        anchors.centerIn: parent
        text: root.icon
        font: Theme.font.base
        color: root.isHovered ? Theme.colors.white : Theme.colors.text

        Behavior on color {
            ColorAnimation {
                duration: root.animationDuration
            }
        }
    }
}
