import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import qs.common
import qs.common.components.controls
import qs.common.components
import qs.services

ZendaPanel {
    id: root

    name: "notifications"
    padding: 16
    targetWidth: 460
    targetHeight: Math.min(680, parent.height - Theme.barSize - 48)
    targetX: parent.width - width - 8

    // Each opening starts at the newest notification; while open, the
    // position is kept.
    onOpenChanged: if (open) notificationList.positionViewAtBeginning()
    Component.onCompleted: if (open) notificationList.positionViewAtBeginning()

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Notificaciones"
                    color: Theme.colors.text
                    font: Theme.font.title
                }

                Text {
                    text: Notifications.unreadNotifications.length === 1
                        ? "1 pendiente"
                        : `${Notifications.unreadNotifications.length} pendientes`
                    color: Theme.colors.overlay
                    font: Theme.font.caption
                }
            }

            ZendaIconButton {
                active: Notifications.dndEnabled
                icon: Notifications.dndEnabled ? Theme.notifications.icon.dnd_none : Theme.notifications.icon.none
                accessibleLabel: Notifications.dndEnabled
                    ? "Desactivar no molestar"
                    : "Activar no molestar"
                onClicked: Notifications.toggleDnd()
            }

            ZendaIconButton {
                icon: "󰆴"
                accessibleLabel: "Borrar todas las notificaciones"
                enabled: Notifications.unreadNotifications.length > 0
                onClicked: Notifications.dismissAll()
            }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                visible: Notifications.unreadNotifications.length === 0
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰂜"
                    color: Theme.colors.overlay
                    font.family: Theme.font.icon.family
                    font.pixelSize: Theme.scaled(36)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Todo al día"
                    color: Theme.colors.text
                    font: Theme.font.title
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Las notificaciones pendientes aparecerán aquí."
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                }
            }

            ListView {
                id: notificationList
                anchors.fill: parent
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                rightMargin: notificationScrollBar.visible ? notificationScrollBar.width + 6 : 0
                // ScriptModel applies only the differences between arrays, so
                // dismissing one notification keeps the scroll position and
                // plays the remove transition instead of rebuilding the list.
                model: ScriptModel {
                    values: Notifications.recentNotifications
                    objectProp: "id"
                }

                ScrollBar.vertical: ScrollBar {
                    id: notificationScrollBar
                    policy: notificationList.contentHeight > notificationList.height
                        ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    visible: policy === ScrollBar.AlwaysOn
                    width: 6
                    padding: 0

                    background: Rectangle {
                        radius: width / 2
                        color: Theme.colors.surface
                    }

                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: width / 2
                        color: notificationScrollBar.pressed || notificationScrollBar.hovered
                            ? Theme.colors.overlay : Theme.colors.surfaceVariant
                    }
                }
                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "y"
                            from: 18
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "x"
                            to: notificationList.width + 32
                            duration: 190
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: 170
                        }
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: NotificationCard {
                    required property var modelData
                    width: notificationList.width - notificationList.rightMargin
                    height: implicitHeight
                    notification: modelData
                    onDismissRequested: id => Notifications.dismiss(id)
                }
            }
        }
    }
}
