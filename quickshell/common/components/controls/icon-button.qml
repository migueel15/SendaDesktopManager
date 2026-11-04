import QtQuick

import qs.common

// Material 3 style round icon button. Standard by default (transparent until
// hovered); tonal gives it a resting fill; active lights it like a selected
// toggle, e.g. Do Not Disturb turned on. Presses squash with a spring.
Rectangle {
    id: root

    property string icon: ""
    property string accessibleLabel: ""
    property bool active: false
    property bool tonal: false
    property real size: Theme.barButtonSize
    property color iconColor: active ? Theme.colors.primary : Theme.colors.text

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: Theme.rounding.full
    color: active ? Theme.colors.selection
        : hover.hovered && enabled ? Theme.colors.surfaceVariant
        : tonal ? Theme.colors.surfaceRaised : "transparent"
    opacity: enabled ? 1 : 0.4
    scale: tap.pressed ? Theme.motion.pressScale - 0.05 : 1

    Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    Behavior on scale { SpringAnimation { spring: Theme.motion.spring + 1; damping: Theme.motion.damping } }

    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        font: Theme.font.icon
        Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
    }

    HoverHandler { id: hover; enabled: root.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: root.enabled; onTapped: root.clicked() }
}
