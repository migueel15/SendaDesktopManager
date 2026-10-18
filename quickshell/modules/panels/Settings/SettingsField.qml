import QtQuick

import qs.common

// Single-line text input in the Senda style. Set secret to hide the text.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool secret: false

    signal accepted()

    implicitHeight: 32
    radius: Theme.rounding.small
    color: Theme.colors.background
    border.width: 1
    border.color: input.activeFocus ? Theme.colors.primary : Theme.colors.surfaceVariant

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        selectByMouse: true
        color: Theme.colors.text
        font.family: Theme.font.base.family
        font.pixelSize: Theme.scaled(12)
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        onAccepted: root.accepted()
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        visible: input.text === ""
        text: root.placeholder
        color: Theme.colors.overlay
        font.family: Theme.font.base.family
        font.pixelSize: Theme.scaled(12)
    }
}
