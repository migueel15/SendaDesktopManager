import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

import qs.common
import qs.common.components
import qs.common.widgets
import qs.common.popups.ControlCenter.components

Item {
    id: root

    property bool isOpen: false
    property int targetX: 0
    property int targetY: 0

    width: 500
    height: content.implicitHeight
    implicitHeight: height

    x: targetX
    y: isOpen ? targetY : -height

    visible: opacity > 0
    opacity: isOpen ? 1 : 0

    Behavior on y {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    function open() {
        isOpen = true;
    }

    function close() {
        isOpen = false;
    }

    // MouseArea to prevent clicks from propagating to PopupController
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
