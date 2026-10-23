pragma ComponentBehavior: Bound

import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import qs.common
import qs.services
import qs.common.components
import qs.common.components.icons
import qs.common.components.barextension as BarComponents

Rectangle {
    id: root

    readonly property Repeater items: itemsRepeater
    property bool expanded: false
    readonly property font emptyStateFont: Theme.font.overlay
    readonly property color emptyStateColor: Theme.colors.overlay
    readonly property bool hasTrayItems: SystemTray.items.values.length > 0

    function isPinned(id) {
        return TrayPins.isPinned(id);
    }

    readonly property var pinnedItems: {
        const liveItems = SystemTray.items.values;
        const result = [];
        for (const id of TrayPins.pinnedIds) {
            for (const item of liveItems) {
                if (item.id === id)
                    result.push(item);
            }
        }
        return result;
    }
    readonly property int unpinnedCount: {
        let count = 0;
        for (const item of SystemTray.items.values) {
            if (!TrayPins.isPinned(item.id))
                count++;
        }
        return count;
    }
    readonly property bool trayMenuOpen: {
        for (let i = 0; i < itemsRepeater.count; i++) {
            const item = itemsRepeater.itemAt(i) as TrayItem;
            if (item && !item.pinned && item.menuOpen) return true;
        }
        return false;
    }

    clip: false
    visible: width > 0 && height > 0 // To avoid warnings about being visible with no size

    height: parent.height
    implicitWidth: pinnedZone.width + (pinnedZone.width > 0 ? 4 : 0) + expandButton.width
    color: "transparent"

    Row {
        id: pinnedZone
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.pinnedItems
            delegate: TrayItem { pinned: true }
        }
    }

    // Expand/collapse button
    Rectangle {
        id: expandButton
        height: Theme.barButtonSize
        width: Theme.barButtonSize
        radius: Theme.rounding.normal
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: pinnedZone.right
        anchors.leftMargin: pinnedZone.width > 0 ? 4 : 0

        // Same hover pill as the other bar buttons; stays lit while expanded.
        color: expandButtonHover.hovered || root.expanded ? Theme.colors.surfaceVariant : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        // Hovering the button keeps the tray open; it closes after leaving,
        // the same way the Spotify and Discord widgets do.
        HoverHandler {
            id: expandButtonHover
        }

        IconSlot {
            anchors.centerIn: parent
            icon: ""
            iconColor: Theme.colors.text
            iconFont: Theme.font.icon
            slotWidth: 24
            slotHeight: 24
            gapAfter: 0
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: root.expanded ? 180 : 360
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: expandButtonMouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    PopupWindow {
        id: trayExtension

        anchor.window: root.QsWindow.window
        anchor.rect.x: {
            const window = root.QsWindow.window;
            if (!window) return 0;
            const point = expandButton.mapToItem(window.contentItem, 0, 0);
            return point.x + expandButton.width - implicitWidth + 20;
        }
        anchor.rect.y: root.QsWindow.window
                ? root.QsWindow.window.contentItem.height
                : 0
        anchor.rect.width: 1
        anchor.rect.height: 1

        implicitWidth: layout.implicitWidth + 24 + 2 * Theme.barBorderRadius
        // Size the window for the open extension, so the unfold animates inside it
        // instead of resizing the Wayland surface on every frame. Growing the
        // window while shrinking keeps a resize animation from being cut off.
        implicitHeight: Math.max(1, trayExtensionContent.expandedHeight, trayExtensionContent.height)
        // Let clicks below the visible shape reach the windows underneath.
        mask: Region {
            item: trayExtensionContent
        }
        visible: root.expanded || trayExtensionContent.height > 0.01
        color: "transparent"

        BarComponents.BarExtension {
            id: trayExtensionContent
            // Hide the last pixels under the bar, without moving the window.
            y: -collapseLift
            width: layout.implicitWidth + 24 + 2 * Theme.barBorderRadius
            expanded: root.expanded
            conflictGroup: "tray-popups"
            autoHideStartsOnExpand: true
            autoHideDelay: 500
            autoHidePaused: root.trayMenuOpen || expandButtonHover.hovered
            onCloseRequested: root.expanded = false

            Row {
                id: layout
                anchors.centerIn: parent
                spacing: 2 // TrayItem includes 3px of clickable padding on each side.

                // Keep tray items at scale 1 while they register or change layout.
                Repeater {
                    id: itemsRepeater
                    model: SystemTray.items
                    delegate: TrayItem {
                        pinned: root.isPinned(modelData.id)
                        visible: !pinned
                    }
                }

                Text {
                    visible: root.hasTrayItems && root.unpinnedCount === 0
                    text: "Todos los iconos están anclados"
                    font: root.emptyStateFont
                    color: root.emptyStateColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
