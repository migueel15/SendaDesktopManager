import Quickshell
import QtQuick
import qs.services

Item {
    id: root

    required property string name
    property var targetX
    property var targetY

    property var targetWidth
    property var targetHeight

    x: targetX ?? 0
    y: targetY ?? 0

    height: targetHeight ?? contentContainer.height
    width: targetWidth ?? contentContainer.width

    default property alias content: contentContainer.data

    visible: OverlayService.currentPanel === name

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: 16
    }
}
