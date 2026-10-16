import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.components
import qs.services

SendaPanel {
    id: root
    name: "notifications"

    padding: 14
    targetWidth: 420
    targetHeight: parent.height - 90
    targetX: parent.width - width - 10
    targetY: 50

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Notificaciones"
                    color: Theme.colors.text
                    font.family: Theme.font.title.family
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                Text {
                    text: Notifications.unreadNotifications.length === 1
                        ? "1 pendiente" : `${Notifications.unreadNotifications.length} pendientes`
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                }
            }

            HeaderButton {
                text: Notifications.dndEnabled ? "󰂛" : "󰂚"
                label: Notifications.dndEnabled ? "Activar notificaciones" : "Silenciar notificaciones"
                highlighted: Notifications.dndEnabled
                onClicked: Notifications.toggleDnd()
            }
            HeaderButton {
                text: "󰆴"
                label: "Borrar todas"
                enabled: Notifications.unreadNotifications.length > 0
                onClicked: Notifications.dismissAll()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.colors.surfaceVariant
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
                    font: Theme.font.icon
                    font.pixelSize: 34
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
                model: Notifications.unreadNotifications
                delegate: NotificationCard {
                    required property var modelData
                    width: notificationList.width
                    notification: modelData
                    onDismissRequested: id => Notifications.dismiss(id)
                }
            }
        }
    }

    component HeaderButton: Rectangle {
        id: button
        required property string text
        required property string label
        property bool highlighted: false
        signal clicked

        implicitWidth: 34
        implicitHeight: 34
        radius: Theme.rounding.normal
        color: buttonMouse.containsMouse ? Theme.colors.surfaceVariant : Theme.colors.surface
        border.width: 1
        border.color: button.highlighted ? Theme.colors.primary : Theme.colors.surfaceVariant

        Text {
            anchors.centerIn: parent
            text: button.text
            color: button.highlighted ? Theme.colors.primary : Theme.colors.text
            font: Theme.font.icon
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    component NotificationCard: Rectangle {
        id: card
        required property var notification
        signal dismissRequested(string id)

        implicitHeight: cardLayout.implicitHeight + 24
        radius: Theme.rounding.normal
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.surfaceVariant

        RowLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Image {
                id: notificationImage
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                visible: status === Image.Ready
                source: card.notification.image || card.notification.appIcon || ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Text {
                visible: !notificationImage.visible
                text: "󰂚"
                color: Theme.colors.primary
                font: Theme.font.icon
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignHCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: card.notification.appName || "Notificación"
                        color: Theme.colors.text
                        font: Theme.font.overlay
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        text: card.timestampLabel(card.notification.receivedAt)
                        color: Theme.colors.overlay
                        font: Theme.font.overlay
                        font.pixelSize: 10
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: card.notification.summary || ""
                    color: Theme.colors.text
                    font.family: Theme.font.title.family
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: card.notification.body || ""
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                    wrapMode: Text.Wrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Theme.rounding.full
                color: dismissMouse.containsMouse ? Theme.colors.error : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: dismissMouse.containsMouse ? Theme.colors.background : Theme.colors.overlay
                    font: Theme.font.icon
                }
                MouseArea {
                    id: dismissMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.dismissRequested(String(card.notification.id))
                }
            }
        }

        function timestampLabel(value) {
            if (value === undefined || value === null || value === "") return "";
            const date = new Date(value);
            return isNaN(date.getTime()) ? "" : Qt.formatDateTime(date, "HH:mm");
        }
    }
}
