import QtQuick

import qs.common

// Selector that unfolds attached under a control card. The card above should
// square its bottom corners while `attached` is true, so both read as one section.
Item {
    id: root

    property bool expanded: false
    property real contentHeight: 0
    // True while the selector shows, including its closing animation.
    readonly property bool attached: visible

    default property alias content: card.data

    width: parent ? parent.width : 0
    // The card overlaps the bottom border of the card above by one pixel.
    height: Math.max(0, card.height - 1)
    visible: card.height > 0

    Rectangle {
        id: card
        y: -1
        width: parent.width
        height: root.expanded ? root.contentHeight : 0
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.rounding.normal
        bottomRightRadius: Theme.rounding.normal
        // Lighter than the main cards, so the open selector stands out.
        color: Theme.colors.surfaceRaised
        border.width: 1
        border.color: Theme.colors.surfaceVariant
        clip: true

        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        // Thin line where the selector joins the card above.
        Rectangle {
            z: 1
            width: parent.width
            height: 1
            color: Theme.colors.surfaceRaisedBorder
        }
    }
}
