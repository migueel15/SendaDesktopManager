pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import Quickshell.Services.SystemTray
import qs.services

MouseArea {
    id: root

    required property SystemTrayItem modelData

    property int iconSize: 18
    property bool pinned: false
    property bool pinDragEnabled: false
    property bool pinDragging: false
    property bool pinDragEligible: false
    property bool suppressClick: false
    property point pressPosition: Qt.point(0, 0)

    signal pinDragMoved(real globalX, real globalY)
    signal pinDragReleased(real globalX, real globalY)
    signal pinDragCanceled()
    property string observedIconSource: ""
    readonly property bool menuOpen: menu.visible
    readonly property bool usingFallback: trayIcon.usingFallback
    readonly property string publishedIconSource: modelData.icon
    readonly property string desktopIconSource: findDesktopIconSource()
    readonly property string preferredIconSource: publishedIconSource !== ""
            ? publishedIconSource
            : desktopIconSource
    readonly property string secondaryIconSource: preferredIconSource === publishedIconSource
            ? desktopIconSource
            : publishedIconSource

    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    implicitWidth: iconSize + 6
    implicitHeight: iconSize + 6
    cursorShape: Qt.PointingHandCursor
    preventStealing: pinDragEnabled

    Component.onCompleted: observedIconSource = publishedIconSource
    Component.onDestruction: {
        if (pinDragging)
            pinDragCanceled();
    }

    function endPinDrag() {
        pinDragging = false;
        pinDragEligible = false;
    }

    onPressed: event => {
        if (pressedButtons !== event.button)
            return;
        suppressClick = false;
        pinDragEligible = pinDragEnabled && !pinned && event.button === Qt.LeftButton;
        pressPosition = mapToGlobal(event.x, event.y);
    }

    onPositionChanged: event => {
        if (!pinDragEligible)
            return;
        // Global coordinates stay stable if showing the target moves the popup.
        const point = mapToGlobal(event.x, event.y);
        if (!pinDragging && Math.hypot(point.x - pressPosition.x, point.y - pressPosition.y) > Qt.styleHints.startDragDistance) {
            pinDragging = true;
            suppressClick = true;
        }
        if (pinDragging)
            pinDragMoved(point.x, point.y);
    }

    onReleased: event => {
        if (event.button !== Qt.LeftButton)
            return;
        pinDragEligible = false;
        if (pinDragging) {
            const point = mapToGlobal(event.x, event.y);
            pinDragReleased(point.x, point.y);
        }
    }

    onCanceled: {
        pinDragEligible = false;
        if (pinDragging)
            pinDragCanceled();
    }

    function openMenu() {
        const window = root.QsWindow.window;
        if (!window)
            return;
        const pos = root.mapToItem(window.contentItem, 0, root.height);
        menu.toggle(window, pos.x, pos.y + 5);
    }

    function unpin() {
        TrayPins.unpin(modelData.id);
    }

    function pin() {
        TrayPins.pin(modelData.id);
    }

    function findDesktopIconSource() {
        const candidates = [modelData.tooltipTitle, modelData.title, modelData.id];
        for (const candidate of candidates) {
            if (!candidate)
                continue;
            const entry = DesktopEntries.heuristicLookup(candidate);
            if (!entry || !entry.icon)
                continue;
            const source = Quickshell.iconPath(entry.icon, true);
            if (source !== "")
                return source;
        }
        return "";
    }

    onClicked: event => {
        if (suppressClick)
            return;
        if (event.button === Qt.MiddleButton) {
            modelData.secondaryActivate();
        } else if (event.button === Qt.RightButton || modelData.onlyMenu) {
            openMenu();
        } else {
            modelData.activate();
        }
    }

    onWheel: event => {
        const horizontal = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y);
        modelData.scroll(horizontal ? event.angleDelta.x : event.angleDelta.y, horizontal);
        event.accepted = true;
    }

    TrayMenu {
        id: menu
        rootMenu: root.modelData.menu
        showUnpin: root.pinned
        showPin: !root.pinned
        onUnpinRequested: root.unpin()
        onPinRequested: root.pin()
    }

    Connections {
        target: root.modelData

        function onReady() {
            trayIcon.reload();
        }

        function onIconChanged() {
            // A changed URL triggers source reload by itself. Reload explicitly
            // only when an app updates the icon contents behind the same URL.
            if (root.observedIconSource === root.publishedIconSource) {
                Qt.callLater(trayIcon.reload);
            } else {
                root.observedIconSource = root.publishedIconSource;
            }
        }
    }

    // Registration can precede the app's final pixmap/theme setup, sometimes
    // without a subsequent NewIcon signal. Refresh just this new entry twice.
    Timer {
        interval: 1500
        running: true
        onTriggered: trayIcon.reload()
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: trayIcon.reload()
    }

    TrayIcon {
        id: trayIcon
        iconSize: root.iconSize
        source: root.preferredIconSource
        fallbackSource: root.secondaryIconSource
        anchors.centerIn: parent
    }
}
