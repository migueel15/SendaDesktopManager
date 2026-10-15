import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.common
import qs.services

PanelWindow {
    id: root

    WlrLayershell.namespace: "Senda:NotificationPopup"
    anchors {
        top: true
        right: true
    }
    margins.top: 55
    margins.right: 16
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"
    implicitWidth: 390
    implicitHeight: content.implicitHeight
    visible: active

    property var notification: null
    property bool active: false
    property real dragOffset: 0

    Connections {
        target: Notifications
        function onPopupRequested(dto) {
            root.notification = dto;
            root.dragOffset = 0;
            root.active = true;
            popupTimer.restart();
        }
        function onNotificationDismissed(id) {
            if (root.notification && String(root.notification.id) === id) {
                popupTimer.stop();
                root.active = false;
                root.notification = null;
                root.dragOffset = 0;
            }
        }
    }

    Timer {
        id: popupTimer
        interval: 6500
        onTriggered: root.active = false
    }

    Rectangle {
        id: content
        x: root.dragOffset
        width: parent.width
        implicitHeight: popupColumn.implicitHeight + 24
        radius: Theme.rounding.normal
        color: Theme.colors.background
        border.width: 1
        border.color: root.notification && root.notification.urgency >= 2
            ? Theme.colors.warning : Theme.colors.surfaceVariant

        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Column {
            id: popupColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 5

            Text {
                width: parent.width
                text: root.notification ? (root.notification.appName || "Notificación") : ""
                color: Theme.colors.primary
                font: Theme.font.overlay
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.notification ? (root.notification.summary || "") : ""
                color: Theme.colors.text
                font.family: Theme.font.title.family
                font.pixelSize: 15
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: root.notification ? (root.notification.body || "") : ""
                color: Theme.colors.overlay
                font: Theme.font.overlay
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Text {
                width: parent.width
                text: "Desliza a un lado para descartar"
                color: Theme.colors.overlay
                opacity: 0.7
                font: Theme.font.overlay
                font.pixelSize: 10
            }
        }

        MouseArea {
            id: swipeArea
            anchors.fill: parent
            property real startX: 0
            onPressed: mouse => startX = mapToItem(root, mouse.x, mouse.y).x
            onPositionChanged: mouse => {
                if (pressed) root.dragOffset = mapToItem(root, mouse.x, mouse.y).x - startX;
            }
            onReleased: {
                if (Math.abs(root.dragOffset) > 90) {
                    if (root.notification) Notifications.dismiss(String(root.notification.id));
                    popupTimer.stop();
                    root.active = false;
                    root.dragOffset = 0;
                } else {
                    root.dragOffset = 0;
                }
            }
        }
    }
}
