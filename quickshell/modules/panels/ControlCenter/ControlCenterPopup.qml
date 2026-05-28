import QtQuick

import qs.common
import qs.modules.panels.ControlCenter.components
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.common.components

SendaPanel {
    id: root
    name: "controlCenter"

    targetWidth: 500
    targetHeight: container.implicitHeight

    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: {
            userCard.closeSystemMenu();
            // mouse.accepted = true;
        }
        // onReleased: mouse => mouse.accepted = true
        // onClicked: mouse => mouse.accepted = true
    }

    Rectangle {
        id: container
        anchors.fill: parent
        color: "transparent"
        radius: 10
        implicitHeight: mainContainer.implicitHeight

        MouseArea {
            anchors.fill: parent
            onPressed: userCard.closeSystemMenu()
            propagateComposedEvents: true
        }

        Column {
            id: mainContainer
            // anchors.fill: parent
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 15

            UserCard {
                id: userCard
            }
            AudioControl {}
            BluetoothControl {}
        }
    }
}
