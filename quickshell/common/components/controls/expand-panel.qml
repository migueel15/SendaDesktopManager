import QtQuick

import qs.common

// Material 3 style selector that unfolds under a card as its own surface,
// separated by a small gap, with rounded corners and a fade + grow animation.
// Put ZendaListItem rows inside and set contentHeight to their height.
Item {
    id: root

    property bool expanded: false
    property real contentHeight: 0
    // Kept for cards that square their corners while a selector is attached.
    // Style B selectors are detached, so cards keep their radius.
    readonly property bool attached: false
    readonly property real gap: Theme.spacing.xs

    default property alias content: surface.data

    width: parent ? parent.width : 0
    height: surface.height > 0 ? surface.height + gap : 0
    visible: surface.height > 0

    Rectangle {
        id: surface
        y: root.gap
        width: parent.width
        height: root.expanded ? root.contentHeight : 0
        radius: Theme.card.radius
        color: Theme.colors.surfaceVariant
        opacity: root.expanded ? 1 : 0
        clip: true

        Behavior on height { NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
    }
}
