import QtQuick
import Quickshell
import Quickshell.Io

import qs.common
import qs.services

Rectangle {
    id: root
    height: parent.height
    width: textIcon.implicitWidth
    color: "transparent"

    readonly property string currentIcon: {
        if (Notifications.dndEnabled && !Notifications.hasNotifications)
            return Theme.notifications.icon.dnd_none;
        if (Notifications.hasNotifications)
            return Theme.notifications.icon.notification;
        return Theme.notifications.icon.none;
    }
    readonly property bool mutedWithPending: Notifications.dndEnabled && Notifications.hasNotifications

    Process {
        id: notifications_popup
        running: false
        command: ["swaync-client", "-t"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                notifications_popup.running = true;
            } else if (event.button === Qt.RightButton) {
                Notifications.toggleDnd();
            }
        }
    }

    Text {
        id: textIcon
        anchors.centerIn: parent
        color: Theme.colors.text
        font: Theme.font.base
        text: root.currentIcon
    }

    Rectangle {
        visible: root.mutedWithPending
        width: 24
        height: 3
        radius: 1
        color: "#80000000"
        rotation: 45
        anchors.centerIn: textIcon
        anchors.horizontalCenterOffset: -2
        anchors.verticalCenterOffset: -1
    }

    Rectangle {
        visible: root.mutedWithPending
        width: 24
        height: 2
        radius: 1
        color: Theme.colors.text
        rotation: 45
        anchors.centerIn: textIcon
        anchors.horizontalCenterOffset: -1
        anchors.verticalCenterOffset: -1
    }
}
