import QtQuick

import qs.common

// Material 3 state layer: the shared hover and press feedback. Place it as the
// first child of the element it covers, so the content stays on top. It fills
// the parent and copies its radius, so it follows the rounding setting.
Rectangle {
    property bool hovered: false
    property bool pressed: false
    property bool focused: false

    anchors.fill: parent
    radius: parent ? parent.radius ?? 0 : 0
    color: focused ? Theme.colors.focus : Theme.stateLayer.color
    opacity: pressed || focused ? Theme.stateLayer.pressedOpacity
        : hovered ? Theme.stateLayer.hoverOpacity : 0
    Behavior on opacity { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
}
