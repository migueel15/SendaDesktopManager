import QtQuick

import qs.common

// Material 3 style selector that unfolds under a card as its own surface,
// separated by a small gap, with rounded corners and a fade + grow animation.
// Put ZendaListItem rows inside and set contentHeight to their height.
//
// One progress value drives everything (height, gap, fade and content lift),
// so the panel and the items below it move together until the very end.
Item {
    id: root

    property bool expanded: false
    property real contentHeight: 0
    // Kept for cards that square their corners while a selector is attached.
    // Style B selectors are detached, so cards keep their radius.
    readonly property bool attached: false
    readonly property real gap: Theme.spacing.xs

    default property alias content: inner.data

    // 0 closed, 1 open.
    property real progress: expanded ? 1 : 0
    Behavior on progress {
        NumberAnimation { duration: Theme.motion.slow + 60; easing.type: Easing.OutQuint }
    }

    width: parent ? parent.width : 0
    // The gap shrinks with the panel, so nothing jumps when it ends.
    height: (root.contentHeight + root.gap) * root.progress
    visible: root.progress > 0

    Rectangle {
        id: surface
        y: root.gap * root.progress
        width: parent.width
        height: Math.max(0, root.height - y)
        radius: Math.min(Theme.card.radius, height / 2)
        color: Theme.colors.surfaceVariant
        // Fades over the last part of the closing, never before it ends.
        opacity: Math.min(1, root.progress * 3)
        clip: true

        Item {
            id: inner
            width: parent.width
            // Content keeps its full height and lifts slightly while closing,
            // instead of being squashed.
            height: root.contentHeight
            y: -(1 - root.progress) * Theme.spacing.md
            opacity: Math.min(1, root.progress * 2)
        }
    }
}
