import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.common
import qs.common.components.controls
import qs.services

// Bar notice for a newer Zenda release. At rest it is a round download button;
// on hover it unfolds with the versions and a dismiss action, and a tooltip
// lists the recent changes. Clicking the button starts the update.
Item {
    id: root

    property string screenName: ""

    readonly property bool expanded: pillHover.hovered || ZendaUpdate.installing
    readonly property int buttonSize: 24
    readonly property int maxChanges: 6

    visible: ZendaUpdate.noticeVisible
    implicitHeight: buttonSize
    implicitWidth: pill.width

    function changeLine(change) {
        const summary = change.summary.charAt(0).toUpperCase() + change.summary.slice(1);
        return "• " + (change.scope ? change.scope + ": " : "") + summary;
    }

    readonly property var shownChanges: ZendaUpdate.changes.slice(0, maxChanges)
    readonly property int hiddenChanges: Math.max(0, ZendaUpdate.changes.length - maxChanges)

    Rectangle {
        id: pill

        height: root.buttonSize
        width: root.expanded ? root.buttonSize + details.implicitWidth : root.buttonSize
        radius: Theme.rounding.full
        color: Theme.colors.surfaceVariant
        ZendaStateLayer { hovered: downloadMouse.containsMouse && !ZendaUpdate.installing; pressed: downloadMouse.pressed }
        clip: true

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        HoverHandler {
            id: pillHover
        }

        Text {
            id: icon
            x: 0
            width: root.buttonSize
            height: root.buttonSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: ZendaUpdate.installing ? "󰔟" : String.fromCodePoint(0xF019)
            color: downloadMouse.containsMouse && !ZendaUpdate.installing
                ? Theme.colors.background : Theme.colors.primary
            font: Theme.font.icon

            RotationAnimator on rotation {
                running: ZendaUpdate.installing
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
                onRunningChanged: if (!running) icon.rotation = 0
            }
        }

        MouseArea {
            id: downloadMouse
            x: 0
            width: root.buttonSize
            height: root.buttonSize
            hoverEnabled: true
            enabled: !ZendaUpdate.installing
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: ZendaUpdate.install()
        }

        Row {
            id: details
            x: root.buttonSize
            height: root.buttonSize
            spacing: 8
            rightPadding: 8
            opacity: root.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ZendaUpdate.installing ? "Actualizando…"
                    : `${ZendaUpdate.current} → ${ZendaUpdate.latest}`
                color: Theme.colors.text
                font: Theme.font.caption
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !ZendaUpdate.installing
                text: "×"
                color: dismissMouse.containsMouse ? Theme.colors.text : Theme.colors.overlay
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(14)

                MouseArea {
                    id: dismissMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ZendaUpdate.dismiss()
                }
            }
        }
    }

    LazyLoader {
        active: pillHover.hovered && root.shownChanges.length > 0 && !ZendaUpdate.installing

        PopupWindow {
            anchor.item: pill
            anchor.rect.x: 0
            anchor.rect.y: pill.height + 10
            anchor.rect.width: pill.width
            anchor.rect.height: 1
            implicitWidth: tip.implicitWidth + 24
            implicitHeight: tip.implicitHeight + 16
            visible: true
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: Theme.rounding.small
                color: Theme.colors.surfaceRaised
                border.width: 1
                border.color: Theme.colors.surfaceRaisedBorder

                Column {
                    id: tip
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: `Novedades de ${ZendaUpdate.latest}`
                        color: Theme.colors.primary
                        font: Theme.font.label
                    }

                    Repeater {
                        model: root.shownChanges

                        Text {
                            required property var modelData
                            width: Math.min(implicitWidth, 320)
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: root.changeLine(modelData)
                            color: Theme.colors.textMuted
                            font: Theme.font.caption
                        }
                    }

                    Text {
                        visible: root.hiddenChanges > 0
                        text: `y ${root.hiddenChanges} más`
                        color: Theme.colors.overlay
                        font: Theme.font.caption
                    }
                }
            }
        }
    }
}
