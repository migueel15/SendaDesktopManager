import QtQuick

import qs.common

// Text button in the Senda style. It dims while disabled.
Rectangle {
    id: root

    property string label: ""
    property bool primary: false

    signal clicked()

    implicitWidth: buttonText.implicitWidth + 24
    implicitHeight: 30
    radius: Theme.rounding.small
    color: mouse.pressed && enabled ? Theme.colors.surfaceVariant : root.primary ? Theme.colors.primary : "transparent"
    border.width: root.primary ? 0 : 1
    border.color: Theme.colors.surfaceVariant
    opacity: enabled ? 1 : 0.4

    Text {
        id: buttonText
        anchors.centerIn: parent
        text: root.label
        color: root.primary ? Theme.colors.background : Theme.colors.text
        font.family: Theme.font.overlay.family
        font.pixelSize: Theme.scaled(12)
        font.weight: Font.Bold
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
