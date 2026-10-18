import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

import qs.common
import qs.services

Variants {
    id: popupLayers

    model: Quickshell.screens

    delegate: PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "Senda:NotificationPopup:" + modelData.name
    anchors {
        top: true
        right: true
    }
    margins.top: 55
    margins.right: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"
    implicitWidth: 430
    implicitHeight: Math.max(120, screen.height - margins.top - 16)
    visible: Notifications.activePopups.count > 0
    mask: Region { item: popupList }

    ListView {
        id: popupList
        anchors {
            top: parent.top
            right: parent.right
            rightMargin: 20
        }
        width: 390
        height: Math.min(contentHeight, root.implicitHeight)
        spacing: 0
        clip: false
        model: Notifications.activePopups

        add: Transition {
            NumberAnimation {
                property: "x"
                from: root.width - popupList.x
                to: 0
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        delegate: Item {
            id: popupEntry

            property bool belongsToScreen: String(model.screenName) === String(root.screen.name)

            width: popupList.width
            height: belongsToScreen ? notificationCard.implicitHeight + 10 : 0

            NotificationPopupCard {
                id: notificationCard
                visible: popupEntry.belongsToScreen
                notificationId: model.notificationId
                expiresAt: model.expiresAt
                expiring: model.isFading
                width: popupList.width
                onDismissRequested: id => Notifications.dismiss(id)
            }
        }
    }

    component NotificationPopupCard: Item {
        id: card

        property string notificationId: ""
        property var notification: Notifications.notificationForId(notificationId)
        property double expiresAt: 0
        property bool expiring: false
        signal dismissRequested(string id)
        property bool dismissing: false
        property real swipeOffset: 0
        property int swipeExitDuration: 280

        implicitHeight: popupColumn.implicitHeight + 24
        transform: Translate {
            x: card.swipeOffset
        }

        onExpiringChanged: {
            if (expiring) {
                if (!dismissing)
                    expireAnimation.start();
            } else {
                expireAnimation.stop();
                if (!dismissing)
                    card.opacity = 1;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.normal
            color: Theme.colors.background
        }

        // Keep card activation below the content so hyperlinks retain their
        // own target and the swipe handler can still take over a drag.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: card.notification
                && Notifications.canActivateNotification(String(card.notification.id))
                ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (card.notification)
                    Notifications.activate(String(card.notification.id));
            }
        }

        HoverHandler {
            onHoveredChanged: Notifications.setPopupHovered(card.notificationId, hovered)
        }

        DragHandler {
            id: swipeHandler
            target: null
            yAxis.enabled: false

            onTranslationChanged: {
                if (active && !card.dismissing)
                    card.swipeOffset = Math.max(0, translation.x);
            }

            onActiveChanged: {
                if (!active) {
                    if (card.swipeOffset >= Math.max(90, card.width * 0.25)) {
                        expireAnimation.stop();
                        card.opacity = 1;
                        card.dismissing = true;
                        const remainingDistance = card.width + 32 - card.swipeOffset;
                        const releaseSpeed = Math.max(700, Math.min(2200, swipeHandler.centroid.velocity.x));
                        card.swipeExitDuration = Math.max(90, Math.round(remainingDistance * 1000 / releaseSpeed));
                        dismissAnimation.start();
                    } else {
                        card.swipeOffset = 0;
                    }
                }
            }
        }

        Column {
            id: popupColumn
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 3

            RowLayout {
                width: parent.width
                spacing: 8

                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26

                    IconImage {
                        id: popupAppIcon
                        anchors.fill: parent
                        source: Notifications.applicationIconSource(card.notification)
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.fill: parent
                        text: "󰂚"
                        color: Theme.colors.primary
                        font: Theme.font.icon
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        visible: !popupAppIcon.visible
                    }
                }

                Text {
                    id: applicationName
                    Layout.fillWidth: true
                    text: card.notification ? (card.notification.appName || "Notificación") : ""
                    color: Theme.colors.primary
                    font: Theme.font.overlay
                    elide: Text.ElideRight

                    HoverHandler {
                        enabled: card.notification
                            && Notifications.canFocusApplication(String(card.notification.id))
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                Text {
                    text: card.notification ? card.timestampLabel(card.notification.receivedAt) : ""
                    color: Theme.colors.overlay
                    font.family: applicationName.font.family
                    font.pixelSize: applicationName.font.pixelSize
                    font.weight: applicationName.font.weight
                }
            }

            Text {
                width: parent.width
                text: card.notification ? (card.notification.summary || "") : ""
                color: Theme.colors.text
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(15)
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight

                HoverHandler {
                    enabled: card.notification
                        && Notifications.canActivateNotification(String(card.notification.id))
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Text {
                width: parent.width
                visible: text.length > 0
                text: card.notification ? (card.notification.body || "") : ""
                color: Theme.colors.overlay
                font: Theme.font.overlay
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.RichText
                linkColor: Theme.colors.primary
                onLinkActivated: link => Notifications.openBodyLink(link)
            }

        }

        NumberAnimation {
            id: dismissAnimation
            target: card
            property: "swipeOffset"
            to: card.width + 32
            duration: card.swipeExitDuration
            easing.type: Easing.Linear
            onFinished: card.dismissRequested(String(card.notification.id))
        }

        NumberAnimation {
            id: expireAnimation
            target: card
            property: "opacity"
            from: 1
            to: 0
            duration: Notifications.popupFadeDurationMs
            easing.type: Easing.OutCubic
        }

        function timestampLabel(value) {
            if (value === undefined || value === null || value === "") return "";
            const date = new Date(value);
            return isNaN(date.getTime()) ? "" : Theme.locale.toString(date, "HH:mm");
        }
    }
    }
}
