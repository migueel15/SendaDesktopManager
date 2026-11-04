import QtQuick
import QtQuick.Controls as Controls
import qs.common

// Native button behavior with Zenda's tokens, including keyboard focus.
Controls.AbstractButton {
    id: root
    property string label: ""
    property bool primary: false
    // Filled with the error color, for actions that cannot be undone.
    property bool destructive: false
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
                color: root.primary || root.destructive ? Theme.colors.base : Theme.colors.secondary
                font.family: Theme.textFamily
                font.pixelSize: Theme.scaled(12)
                font.weight: Font.Bold
            }
        }
    }
    scale: root.down ? Theme.motion.pressScale : 1
    Behavior on scale { SpringAnimation { spring: Theme.motion.spring + 1; damping: Theme.motion.damping } }
    background: Rectangle {
        radius: Theme.rounding.full
        color: root.destructive ? (root.hovered ? Qt.lighter(Theme.colors.error, 1.1) : Theme.colors.error)
            : root.primary ? (root.hovered ? Theme.colors.secondary : Theme.colors.primary)
            : root.down || root.hovered ? Theme.colors.surfaceVariant : Theme.colors.selection
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
        border.width: root.visualFocus ? 2 : 0
        border.color: Theme.colors.focus
    }
}
