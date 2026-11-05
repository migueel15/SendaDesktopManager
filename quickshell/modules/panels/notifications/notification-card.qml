import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import qs.common
import qs.common.components.controls
import qs.services

// One notification card, shared by the popups and the panel. It owns the
// background, activation, swipe to dismiss and the content layout, so both
// places keep the same margins and hierarchy.
Item {
    id: card

    property var notification: null
    // Lines shown before eliding; the popup keeps these shorter.
    property int summaryLines: 3
    property int bodyLines: 5
    // Shows a dismiss button in place of the time while hovered.
    property bool showDismissButton: true
    readonly property bool hovered: cardHover.hovered
    property bool dismissing: false
    property real swipeOffset: 0
    property int swipeExitDuration: 280
    property double now: Date.now()

    signal dismissRequested(string id)

    readonly property string notificationKey: notification ? String(notification.id) : ""
    readonly property bool canActivate: notification !== null
        && Notifications.canActivateNotification(notificationKey)

    implicitHeight: contentRow.implicitHeight + 2 * Theme.spacing.lg
    transform: Translate {
        x: card.swipeOffset
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.card.radius
        color: cardHover.hovered ? Theme.card.hoverFill : Theme.card.fill
        border.width: Theme.card.borderWidth
        border.color: Theme.card.borderColor

        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.normal
            }
        }
    }

    HoverHandler {
        id: cardHover
    }

    // One activation target for the whole card. Declaring it before the
    // content keeps links and the dismiss button on top of this area.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: card.canActivate ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (card.notification)
                Notifications.activate(card.notificationKey);
        }
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
            if (active)
                return;
            if (card.swipeOffset >= Math.max(90, card.width * 0.25)) {
                card.dismissing = true;
                const remainingDistance = card.width + 32 - card.swipeOffset;
                const releaseSpeed = Math.max(700, Math.min(2200, swipeHandler.centroid.velocity.x));
                card.swipeExitDuration = Math.max(90, Math.round(remainingDistance * 1000 / releaseSpeed));
                swipeOutAnimation.start();
            } else {
                card.swipeOffset = 0;
            }
        }
    }

    NumberAnimation {
        id: swipeOutAnimation
        target: card
        property: "swipeOffset"
        to: card.width + 32
        duration: card.swipeExitDuration
        easing.type: Easing.Linear
        onFinished: card.dismissRequested(card.notificationKey)
    }

    // Keeps relative times ("hace 5 min") current.
    Timer {
        interval: 30000
        repeat: true
        running: card.visible
        triggeredOnStart: true
        onTriggered: card.now = Date.now()
    }

    RowLayout {
        id: contentRow
        anchors {
            fill: parent
            margins: Theme.spacing.lg
        }
        spacing: Theme.spacing.md

        // App icon on a tile, so every app gets the same frame.
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignTop
            radius: Theme.rounding.normal
            color: Theme.colors.surfaceVariant

            IconImage {
                id: appIcon
                asynchronous: true
                anchors.fill: parent
                anchors.margins: 6
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
                visible: !appIcon.visible
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.sm

                Text {
                    Layout.fillWidth: true
                    text: card.notification ? (card.notification.appName || "Notificación") : ""
                    color: Theme.colors.overlay
                    font: Theme.font.caption
                    elide: Text.ElideRight

                    HoverHandler {
                        enabled: card.notification !== null
                            && Notifications.canFocusApplication(card.notificationKey)
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                // The time and the dismiss button share one slot, so showing
                // the button on hover never reflows the text.
                Item {
                    Layout.preferredWidth: timeLabel.implicitWidth
                    Layout.preferredHeight: timeLabel.implicitHeight

                    Text {
                        id: timeLabel
                        anchors.right: parent.right
                        text: card.notification ? card.relativeTime(card.notification.receivedAt, card.now) : ""
                        color: Theme.colors.overlay
                        font: Theme.font.caption
                        opacity: dismissButton.visible ? 0 : 1
                    }

                    ZendaIconButton {
                        id: dismissButton
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        size: Theme.scaled(24)
                        visible: card.showDismissButton && cardHover.hovered
                        icon: "󰅖"
                        accessibleLabel: "Descartar notificación"
                        onClicked: {
                            card.dismissing = true;
                            card.dismissRequested(card.notificationKey);
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.xs
                text: card.notification ? (card.notification.summary || "") : ""
                color: Theme.colors.text
                font: Theme.font.heading
                wrapMode: Text.Wrap
                maximumLineCount: card.summaryLines
                elide: Text.ElideRight
                textFormat: Text.PlainText

                HoverHandler {
                    enabled: card.canActivate
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.xxs
                visible: text.length > 0
                text: card.notification ? (card.notification.body || "") : ""
                color: Theme.colors.textMuted
                font: Theme.font.body
                lineHeight: 1.15
                wrapMode: Text.Wrap
                maximumLineCount: card.bodyLines
                elide: Text.ElideRight
                textFormat: Text.RichText
                linkColor: Theme.colors.primary
                onLinkActivated: link => Notifications.openBodyLink(link)
            }

            ClippingRectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.sm
                Layout.preferredHeight: visible
                    ? Math.min(180, previewImage.sourceSize.height * width / Math.max(1, previewImage.sourceSize.width))
                    : 0
                visible: previewImage.source.toString().length > 0 && previewImage.status === Image.Ready
                radius: Theme.rounding.control
                color: Theme.colors.surfaceVariant

                Image {
                    id: previewImage
                    anchors.fill: parent
                    source: card.notification?.screenshotPath ? card.notification.image : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }
    }

    function relativeTime(value, nowMs) {
        if (value === undefined || value === null || value === "")
            return "";
        const date = new Date(value);
        if (isNaN(date.getTime()))
            return "";
        const minutes = Math.floor((nowMs - date.getTime()) / 60000);
        if (minutes < 1)
            return "ahora";
        if (minutes < 60)
            return `hace ${minutes} min`;
        const today = new Date(nowMs);
        today.setHours(0, 0, 0, 0);
        if (date >= today)
            return Theme.locale.toString(date, "HH:mm");
        const yesterday = new Date(today.getTime() - 86400000);
        if (date >= yesterday)
            return "ayer " + Theme.locale.toString(date, "HH:mm");
        return Theme.locale.toString(date, "d MMM");
    }
}
