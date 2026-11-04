import QtQuick
import QtQuick.Controls as Controls
import qs.common

Controls.AbstractButton {
    id: root
    property bool checkedValue: false
    signal toggledValue(bool value)
    implicitWidth: Math.round(implicitHeight * 1.8)
    implicitHeight: Theme.scaled(26)
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checkedValue
    // Animate only changes the user makes: values that arrive when a page is
    // created or data loads snap into place instead of sliding.
    property bool animating: false
    function animateChange() { root.animating = true; settle.restart(); }
    Timer { id: settle; interval: 700; onTriggered: root.animating = false }
    onClicked: { root.animateChange(); toggledValue(!checkedValue); }
    background: Rectangle {
        radius: Theme.rounding.full
        color: root.checkedValue ? Theme.colors.primary : Theme.colors.surfaceVariant
        border { width: root.visualFocus ? 2 : 0; color: Theme.colors.focus }
        Behavior on color { enabled: root.animating; ColorAnimation { duration: Theme.motion.normal } }
        Rectangle {
            // The thumb grows when on and slides with a spring.
            property real thumbSize: parent.height * (root.checkedValue ? 0.7 : 0.46)
            x: root.checkedValue ? parent.width - thumbSize - (parent.height - thumbSize) / 2 : parent.height * 0.27
            anchors.verticalCenter: parent.verticalCenter
            width: thumbSize
            height: thumbSize
            radius: Theme.rounding.full
            color: root.checkedValue ? Theme.colors.base : Theme.colors.overlay
            Behavior on x { enabled: root.animating; SpringAnimation { spring: Theme.motion.spring; damping: Theme.motion.damping } }
            Behavior on thumbSize { enabled: root.animating; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack } }
        }
    }
}
