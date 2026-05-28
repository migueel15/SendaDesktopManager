import Quickshell
import QtQuick
import qs.common
import qs.services

Item {
    id: root

    required property string name
    property var targetX
    property var targetY

    property var targetWidth
    property var targetHeight

    property int padding: 16

    default property alias content: contentItem.data

    x: targetX ?? 0
    y: targetY ?? 0

    height: targetHeight + padding * 2 ?? container.height
    width: targetWidth ?? container.width

    visible: OverlayService.currentPanel === name

    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: {
            mouse.accepted = true;
        }
        onReleased: mouse => mouse.accepted = true
        onClicked: mouse => mouse.accepted = true
    }

    Rectangle {
        id: container
        anchors.fill: parent

        color: Theme.colors.background
        radius: 10

        border.width: 1
        border.color: Theme.colors.surfaceVariant

        Item {
            id: contentItem

            anchors.fill: parent
            anchors.margins: root.padding
        }
    }
}
