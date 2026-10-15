import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import qs.common
import qs.common.components
import qs.common.components.icons

Rectangle {
    id: root

    readonly property Repeater items: items
    property bool expanded: false
    readonly property real revealProgress: expanded ? 1 : 0

    clip: true
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
                    duration: 180
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
        id: trayPopup

        anchor.window: root.QsWindow.window
        anchor.rect.x: {
            const window = root.QsWindow.window;
            if (!window) return 0;
            const point = expandButton.mapToItem(window.contentItem, 0, 0);
            return point.x + expandButton.width - width;
        }
        anchor.rect.y: root.QsWindow.window
                ? root.QsWindow.window.contentItem.height
                : 0
        anchor.rect.width: 1
        anchor.rect.height: 1

        width: trayContent.implicitWidth
        height: root.expanded ? Theme.barSize : 1
        visible: root.expanded || height > 1
        color: "transparent"

        Behavior on height {
            NumberAnimation {
                duration: root.expanded ? 110 : 220
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: trayContent
            width: parent.width
            implicitWidth: layout.implicitWidth + 24 + 2 * Theme.barBorderRadius
            height: parent.height

            Canvas {
                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Theme.colors.background;

                    const left = Theme.barBorderRadius;
                    const right = width - Theme.barBorderRadius;
                    const r = Math.min(Theme.barBorderRadius, (right - left) / 2, height / 2);
                    ctx.beginPath();
                    ctx.moveTo(left, 0);
                    ctx.lineTo(right, 0);
                    ctx.lineTo(right, height - r);
                    ctx.quadraticCurveTo(right, height, right - r, height);
                    ctx.lineTo(left + r, height);
                    ctx.quadraticCurveTo(left, height, left, height - r);
                    ctx.lineTo(left, 0);
                    ctx.closePath();
                    ctx.fill();
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            BarCorner {
                x: 0
                y: 0
                position: "top-right"
                shapeColor: Theme.colors.background
                cornerRadius: Theme.barBorderRadius
            }

            BarCorner {
                x: parent.width - Theme.barBorderRadius
                y: 0
                position: "top-left"
                shapeColor: Theme.colors.background
                cornerRadius: Theme.barBorderRadius
            }

            Row {
                id: layout
                anchors.centerIn: parent
                spacing: 2 // TrayItem includes 3px of clickable padding on each side.
                opacity: root.revealProgress

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.expanded ? 80 : 140
                        easing.type: Easing.OutQuad
                    }
                }

                // Items may register while the drawer is hidden. Keep their visual
                // and input scale at 1 throughout insertion and layout changes.

                Repeater {
                    id: items
                    model: SystemTray.items
                    delegate: TrayItem {}
                }
            }
        }
    }
}
