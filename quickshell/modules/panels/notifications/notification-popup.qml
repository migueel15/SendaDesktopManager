import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import qs.common
import qs.services

Variants {
    id: popupLayers

    model: Notifications.activePopups.count > 0 ? Quickshell.screens : []

    delegate: PanelWindow {
        id: root

        required property var modelData
        screen: modelData

        WlrLayershell.namespace: "Zenda:NotificationPopup:" + modelData.name
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

            populate: Transition {
                NumberAnimation {
                    property: "x"
                    from: root.width - popupList.x
                    to: 0
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
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
                height: belongsToScreen ? notificationCard.implicitHeight + Theme.spacing.sm : 0

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

    component NotificationPopupCard: NotificationCard {
        id: card

        property string notificationId: ""
        property double expiresAt: 0
        property bool expiring: false

        notification: Notifications.notificationForId(notificationId)
        summaryLines: 2
        bodyLines: 4
        showDismissButton: false

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

        // A swipe takes over from the fade-out.
        onDismissingChanged: {
            if (dismissing) {
                expireAnimation.stop();
                card.opacity = 1;
            }
        }

        onHoveredChanged: {
            Notifications.setPopupHovered(card.notificationId, hovered);
            lifetimeBar.restart();
        }

        onExpiresAtChanged: lifetimeBar.restart()

        // Remaining lifetime of the popup, kept inside the straight part of
        // the bottom edge. Full while hovered, since hovering pauses the
        // timeout.
        Rectangle {
            id: lifetimeBar
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: Theme.card.radius
                bottomMargin: Theme.spacing.xs
            }
            readonly property real fullWidth: card.width - 2 * Theme.card.radius
            property real progress: 1
            width: fullWidth * progress
            height: 3
            radius: height / 2
            color: Theme.colors.primary
            opacity: 0.7

            NumberAnimation on progress {
                id: lifetimeAnimation
                running: false
                to: 0
            }

            function restart() {
                lifetimeAnimation.stop();
                const remaining = card.expiresAt - Date.now();
                progress = Math.max(0, Math.min(1, remaining / Notifications.popupLifetimeMs));
                if (card.hovered || remaining <= 0)
                    return;
                lifetimeAnimation.duration = remaining;
                lifetimeAnimation.start();
            }

            Component.onCompleted: restart()
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
    }
}
}
