import QtQuick

import qs.common
import qs.common.components.icons
import qs.common.components.controls
import qs.services

Item {
    id: root

    // Name of the monitor the bar sits on; panels open there.
    property string screenName: ""

    height: parent.height
    implicitWidth: Theme.barButtonSize

    readonly property string currentIcon: Notifications.dndEnabled
        ? Theme.notifications.icon.dnd_none
        : (Notifications.hasNotifications ? Theme.notifications.icon.notification : Theme.notifications.icon.none)


    // Same hover pill as the control panel button.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Theme.barButtonSize
        radius: Theme.rounding.normal
        color: "transparent"
        ZendaStateLayer { hovered: mouseArea.containsMouse; pressed: mouseArea.pressed }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                OverlayService.togglePanel("notifications", root.screenName);
            } else if (event.button === Qt.RightButton) {
                Notifications.toggleDnd();
            }
        }
    }

    ZendaIcon {
        id: iconText
        anchors.centerIn: parent
        color: Theme.colors.text
        text: root.currentIcon
    }
}
