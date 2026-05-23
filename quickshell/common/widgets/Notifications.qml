import QtQuick
import Quickshell
import Quickshell.Io

import qs.common

Rectangle {
    id: root
    height: parent.height
    width: textIcon.implicitWidth
    color: "transparent"

    property var currentIcon: Theme.notifications.icon.none

    Component.onDestruction: {
        swaync_daemon.running = false;
    }

    Process {
        id: swaync_daemon
        running: true
        command: ["swaync-client", "-swb"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    const alt = data.alt;
                    switch (alt) {
                    case "none":
                        root.currentIcon = Theme.notifications.icon.none;
                        break;
                    case "notification":
                        root.currentIcon = Theme.notifications.icon.notification;
                        break;
                    case "dnd-none":
                        root.currentIcon = Theme.notifications.icon.dnd_none;
                        break;
                    case "dnd-notification":
                        root.currentIcon = Theme.notifications.icon.dnd_notification;
                        break;
                    default:
                        break;
                    }
                } catch (e) {
                    console.error("Error parsing:", e);
                }
            }
        }
    }

    Process {
        id: notifications_popup
        running: false
        command: ["swaync-client", "-t"]
    }

    Process {
        id: dnd_toggle
        running: false
        command: ["swaync-client", "-d"]
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                notifications_popup.running = true;
            } else if (event.button === Qt.RightButton) {
                dnd_toggle.running = true;
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
}
