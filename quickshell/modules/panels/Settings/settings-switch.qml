import QtQuick
import QtQuick.Controls as Controls
import qs.common

Controls.AbstractButton {
    id: root
    property bool checkedValue: false
    signal toggledValue(bool value)
    implicitWidth: 44
    implicitHeight: Math.max(28, Theme.scaled(22))
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checkedValue
    onClicked: toggledValue(!checkedValue)
    background: Rectangle {
        radius: Theme.rounding.full
        color: root.checkedValue ? Theme.colors.primary : Theme.colors.surfaceVariant
        border { width: 1; color: root.visualFocus ? Theme.colors.focus : Theme.colors.border }
        Rectangle {
            x: root.checkedValue ? parent.width - width - Theme.spacing.xs : Theme.spacing.xs
            y: Theme.spacing.xs
            width: height
            height: parent.height - 2 * Theme.spacing.xs
            radius: Theme.rounding.full
            color: root.checkedValue ? Theme.colors.base : Theme.colors.text
            Behavior on x { NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
        }
    }
}
