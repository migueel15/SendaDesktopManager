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

    // Name of the monitor this panel is drawn on. Set by the overlay that hosts it.
    property string screenName: ""
    // True on the monitor the panel was opened from.
    readonly property bool onOpenScreen: root.screenName !== "" && root.screenName === OverlayService.currentScreen

    visible: OverlayService.currentPanel === name && root.onOpenScreen || Debug.enabled && Debug.panel === name

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
        radius: Theme.rounding.normal

        border.width: 1
        border.color: Theme.colors.surfaceVariant

        Item {
            id: contentItem

            anchors.fill: parent
            anchors.margins: root.padding
        }
    }
}
