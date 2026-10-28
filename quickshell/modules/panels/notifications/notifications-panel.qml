import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs.common
import qs.common.components
import qs.services

SendaPanel {
    id: root

    name: "notifications"
    padding: 16
    targetWidth: 460
    targetHeight: Math.min(680, parent.height - Theme.barSize - 48)
    targetX: parent.width - width - 8

    // Each opening starts at the newest notification; while open, the
    // position is kept.
    onOpenChanged: if (open) notificationList.positionViewAtBeginning()

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

            PanelAction {
                active: Notifications.dndEnabled
                text: Notifications.dndEnabled ? Theme.notifications.icon.dnd_none : Theme.notifications.icon.none
                accessibleLabel: Notifications.dndEnabled
                    ? "Desactivar no molestar"
                    : "Activar no molestar"
                onClicked: Notifications.toggleDnd()
            }

            PanelAction {
                text: "󰆴"
                accessibleLabel: "Borrar todas las notificaciones"
                enabled: Notifications.unreadNotifications.length > 0
                onClicked: Notifications.dismissAll()
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.colors.border
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

                delegate: NotificationRow {
                    required property var modelData
                    width: notificationList.width - notificationList.rightMargin
                    height: implicitHeight
                    notification: modelData
                    onDismissRequested: id => Notifications.dismiss(id)
                }
            }
        }
    }

    component PanelAction: Rectangle {
        id: action

        required property string text
        required property string accessibleLabel
        // Lit like a selected item, e.g. Do Not Disturb turned on.
        property bool active: false
        signal clicked

        // Ghost icon button, the same size as the bar buttons.
        implicitWidth: Theme.barButtonSize
        implicitHeight: Theme.barButtonSize
        radius: Theme.rounding.normal
        color: action.active ? Theme.colors.selection
            : (actionMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent")
        opacity: enabled ? 1 : 0.45

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Text {
            anchors.centerIn: parent
            text: action.text
            color: action.active ? Theme.colors.primary : Theme.colors.text
            font: Theme.font.icon
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: action.enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: action.clicked()
        }
    }

    component NotificationRow: Rectangle {
        id: row

        required property var notification
        signal dismissRequested(string id)
        property bool dismissing: false
        property real swipeOffset: 0
        property int swipeExitDuration: 280

        implicitHeight: rowLayout.implicitHeight + 24
        x: 0
        radius: Theme.rounding.normal
        color: rowHover.hovered ? Theme.colors.surfaceRaised : Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.border
        transform: Translate {
            x: row.swipeOffset
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        HoverHandler {
            id: rowHover
        }

        // One activation target for the whole card. Declaring it before the
        // content keeps links and the dismiss button on top of this area.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: Notifications.canActivateNotification(String(row.notification.id))
                ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Notifications.activate(String(row.notification.id))
        }

        DragHandler {
            id: swipeHandler
            target: null
            yAxis.enabled: false

            onTranslationChanged: {
                if (active && !row.dismissing)
                    row.swipeOffset = Math.max(0, translation.x);
            }

            onActiveChanged: {
                if (!active) {
                    if (row.swipeOffset >= Math.max(90, row.width * 0.25)) {
                        row.dismissing = true;
                        const remainingDistance = row.width + 32 - row.swipeOffset;
                        const releaseSpeed = Math.max(700, Math.min(2200, swipeHandler.centroid.velocity.x));
                        row.swipeExitDuration = Math.max(90, Math.round(remainingDistance * 1000 / releaseSpeed));
                        swipeOutAnimation.start();
                    } else {
                        row.swipeOffset = 0;
                    }
                }
            }
        }

        NumberAnimation {
            id: swipeOutAnimation
            target: row
            property: "swipeOffset"
            to: row.width + 32
            duration: row.swipeExitDuration
            easing.type: Easing.Linear
            onFinished: row.dismissRequested(String(row.notification.id))
        }

        RowLayout {
            id: rowLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // App icon on a tile, like the popups.
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignTop
                radius: Theme.rounding.small
                color: Theme.colors.background
                border.width: 1
                border.color: Theme.colors.border

                IconImage {
                    asynchronous: true
                    id: rowAppIcon
                    anchors.fill: parent
                    anchors.margins: 5
                    source: Notifications.applicationIconSource(row.notification)
                    visible: status === Image.Ready
                }

                Text {
                    anchors.fill: parent
                    text: "󰂚"
                    color: Theme.colors.primary
                    font: Theme.font.icon
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    visible: !rowAppIcon.visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        id: applicationName
                        Layout.fillWidth: true
                        text: row.notification.appName || "Notificación"
                        color: Theme.colors.overlay
                        font: Theme.font.caption
                        elide: Text.ElideRight

                        HoverHandler {
                            enabled: Notifications.canFocusApplication(String(row.notification.id))
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }

                    }

                    Text {
                        text: row.timestampLabel(row.notification.receivedAt)
                        color: Theme.colors.overlay
                        font: Theme.font.caption
                    }
                }

                Item {
                    Layout.preferredHeight: 4
                }

                Text {
                    Layout.fillWidth: true
                    text: row.notification.summary || ""
                    color: Theme.colors.text
                    font: Theme.font.heading
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    textFormat: Text.PlainText

                    HoverHandler {
                        enabled: Notifications.canActivateNotification(String(row.notification.id))
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: row.notification.body || ""
                    color: Theme.colors.textMuted
                    font: Theme.font.body
                    lineHeight: 1.15
                    wrapMode: Text.Wrap
                    maximumLineCount: 5
                    elide: Text.ElideRight
                    textFormat: Text.RichText
                    linkColor: Theme.colors.primary
                    onLinkActivated: link => Notifications.openBodyLink(link)
                }

                Image {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 180 : 0
                    visible: source.toString().length > 0 && status !== Image.Error
                    source: row.notification.screenshotPath ? row.notification.image : ""
                    fillMode: Image.PreserveAspectFit
                }

            }

            // Shown on hover only, to keep the list calm.
            PanelAction {
                Layout.alignment: Qt.AlignTop
                opacity: rowHover.hovered ? 1 : 0
                text: "󰅖"
                accessibleLabel: "Descartar notificación"
                onClicked: {
                    row.dismissing = true;
                    row.dismissRequested(String(row.notification.id));
                }
            }
        }

        function timestampLabel(value) {
            if (value === undefined || value === null || value === "") return "";
            const date = new Date(value);
            return isNaN(date.getTime()) ? "" : Theme.locale.toString(date, "HH:mm");
        }
    }
}
