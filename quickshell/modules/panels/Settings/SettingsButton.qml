import QtQuick
import QtQuick.Controls as Controls
import qs.common

// Native button behavior with Senda's tokens, including keyboard focus.
Controls.AbstractButton {
    id: root
    property string label: ""
    property bool primary: false
    // Shows a spinning reload icon next to the label while work is running.
    property bool busy: false
    implicitWidth: content.implicitWidth + Theme.spacing.xl
    implicitHeight: content.implicitHeight + Theme.spacing.lg
    leftPadding: Theme.spacing.md
    rightPadding: Theme.spacing.md
    topPadding: Theme.spacing.sm
    bottomPadding: Theme.spacing.sm
    opacity: enabled || busy ? 1 : 0.4
    Accessible.name: label
    contentItem: Item {
        id: content
        implicitWidth: contentRow.implicitWidth
        implicitHeight: buttonText.implicitHeight

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Theme.spacing.sm

            Text {
                id: busyIcon
                visible: root.busy
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(0xF021)
                color: buttonText.color
                font.family: Theme.font.overlay.family
                font.pixelSize: Theme.scaled(12)

                RotationAnimation on rotation {
                    running: root.busy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            Text {
                id: buttonText
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: root.primary ? Theme.colors.base : Theme.colors.text
                font.family: Theme.textFamily
                font.pixelSize: Theme.scaled(12)
                font.weight: Font.Bold
            }
        }
    }
    background: Rectangle {
        radius: Theme.rounding.small
        color: root.primary ? (root.hovered ? Theme.colors.secondary : Theme.colors.primary)
            : root.down || root.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface
        border.width: 1
        border.color: root.visualFocus ? Theme.colors.focus : root.primary ? Theme.colors.primary : Theme.colors.border
    }
}
