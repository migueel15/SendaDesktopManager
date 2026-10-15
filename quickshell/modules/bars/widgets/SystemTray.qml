import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import qs.common
import qs.common.components
import qs.common.components.icons
import qs.common.components.barextension as BarComponents

Rectangle {
    id: root

    readonly property Repeater items: itemsRepeater
    property bool expanded: false
    readonly property real extensionLift: trayExtensionContent.collapseLift
    readonly property bool trayMenuOpen: {
        for (let i = 0; i < itemsRepeater.count; i++) {
            const item = itemsRepeater.itemAt(i);
            if (item && item.menuOpen) return true;
        }
        return false;
    }

    clip: false
    visible: width > 0 && height > 0 // To avoid warnings about being visible with no size

    height: parent.height
    implicitWidth: expandButton.width
    color: "transparent"

    // Expand/collapse button
    Rectangle {
        id: expandButton
        height: parent.height * 0.8
        width: 24
        radius: Theme.rounding.normal
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        color: Theme.colors.background

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
                ? root.QsWindow.window.contentItem.height - root.extensionLift
                : 0
        anchor.rect.width: 1
        anchor.rect.height: 1

        implicitWidth: layout.implicitWidth + 24 + 2 * Theme.barBorderRadius
        implicitHeight: Math.max(1, trayExtensionContent.height)
        visible: root.expanded || trayExtensionContent.height > 0.01
        color: "transparent"

        BarComponents.BarExtension {
            id: trayExtensionContent
            width: layout.implicitWidth + 24 + 2 * Theme.barBorderRadius
            expanded: root.expanded
            conflictGroup: "tray-popups"
            autoHidePaused: root.trayMenuOpen
            onCloseRequested: root.expanded = false

            Row {
                id: layout
                anchors.centerIn: parent
                spacing: 2 // TrayItem includes 3px of clickable padding on each side.

                // Keep tray items at scale 1 while they register or change layout.
                Repeater {
                    id: itemsRepeater
                    model: SystemTray.items
                    delegate: TrayItem {}
                }
            }
        }
    }
}
