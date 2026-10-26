import QtQuick
import QtQuick.Controls as Controls
import qs.common

// Native button behavior with Senda's tokens, including keyboard focus.
Controls.AbstractButton {
    id: root
    property string label: ""
    property bool primary: false
    implicitWidth: buttonText.implicitWidth + Theme.spacing.xl
    implicitHeight: buttonText.implicitHeight + Theme.spacing.lg
    leftPadding: Theme.spacing.md
    rightPadding: Theme.spacing.md
    topPadding: Theme.spacing.sm
    bottomPadding: Theme.spacing.sm
    opacity: enabled ? 1 : 0.4
    Accessible.name: label
    contentItem: Text {
        id: buttonText
        text: root.label
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        color: root.primary ? Theme.colors.base : Theme.colors.text
        font.family: Theme.textFamily
        font.pixelSize: Theme.scaled(12)
        font.weight: Font.Bold
    }
    background: Rectangle {
        radius: Theme.rounding.small
        color: root.primary ? (root.hovered ? Theme.colors.secondary : Theme.colors.primary)
            : root.down || root.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface
        border.width: 1
        border.color: root.visualFocus ? Theme.colors.focus : root.primary ? Theme.colors.primary : Theme.colors.border
    }
}
