pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import Quickshell.Services.SystemTray

MouseArea {
    id: root

    required property SystemTrayItem modelData

    property int iconSize: 18
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

    Component.onCompleted: observedIconSource = publishedIconSource

    function openMenu() {
        const window = root.QsWindow.window;
        if (!modelData.hasMenu || !window)
            return;
        const pos = root.mapToItem(window.contentItem, 0, root.height);
        menu.toggle(window, pos.x, pos.y + 5);
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
