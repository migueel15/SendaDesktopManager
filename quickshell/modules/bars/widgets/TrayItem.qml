pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import Quickshell.Services.SystemTray

MouseArea {
    id: root

    required property SystemTrayItem modelData

    property int iconSize: 18
    readonly property bool usingFallback: trayIcon.usingFallback
    readonly property string publishedIconSource: modelData.icon
    readonly property bool publishedIconIsNamed: publishedIconSource.startsWith("image://icon/")
            || publishedIconSource.startsWith("file:")
    readonly property string desktopIconSource: findDesktopIconSource()
    readonly property string preferredIconSource: !publishedIconIsNamed && desktopIconSource !== ""
            ? desktopIconSource
            : publishedIconSource
    readonly property string secondaryIconSource: preferredIconSource === publishedIconSource
            ? desktopIconSource
            : publishedIconSource

    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    implicitWidth: iconSize + 6
    implicitHeight: iconSize + 6
    cursorShape: Qt.PointingHandCursor

    function openMenu() {
        const window = root.QsWindow.window;
        if (!modelData.hasMenu || !window)
            return;
        const pos = root.mapToItem(window.contentItem, 0, root.height);
        menu.anchor.rect.x = pos.x;
        menu.anchor.rect.y = pos.y + 5;
        menu.open();
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

    QsMenuAnchor {
        id: menu
        menu: root.modelData.menu
        anchor.window: root.QsWindow.window
    }

    Connections {
        target: root.modelData

        function onReady() {
            trayIcon.reload();
        }

        function onIconChanged() {
            // Some applications update the contents without changing the URL.
            Qt.callLater(trayIcon.reload);
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
