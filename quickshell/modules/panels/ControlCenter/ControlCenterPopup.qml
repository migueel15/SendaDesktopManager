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
    Item {
        id: item

        width: 500
        height: content.implicitHeight

        MouseArea {
            anchors.fill: parent
            z: -1
            onPressed: {
                userCard.closeSystemMenu();
                mouse.accepted = true;
            }
            onReleased: mouse => mouse.accepted = true
            onClicked: mouse => mouse.accepted = true
        }

        Rectangle {
            id: content
            anchors.fill: parent
            color: Theme.colors.background
            radius: 10
            implicitHeight: mainContainer.implicitHeight + 40

            MouseArea {
                anchors.fill: parent
                onPressed: userCard.closeSystemMenu()
                propagateComposedEvents: true
            }

            Column {
                id: mainContainer
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                UserCard {
                    id: userCard
                }
                AudioControl {}
                BluetoothControl {}
            }
        }
    }
}
