import QtQuick

import qs.common

Item {
    id: root

    property string icon: ""
    property color iconColor: Theme.colors.text
    property font iconFont: Theme.font.title
    property int slotWidth: 24
    property int slotHeight: 24
    property int gapBefore: 0
    property int gapAfter: 8
    property bool interactive: false

    signal clicked

    width: slotWidth + gapBefore + gapAfter
    height: slotHeight
    implicitWidth: width
    implicitHeight: height

    Text {
        x: root.gapBefore
        width: root.slotWidth
        height: root.slotHeight
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.iconColor
        font: root.iconFont
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
