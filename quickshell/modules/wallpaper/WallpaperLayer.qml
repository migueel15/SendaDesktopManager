import Quickshell
import QtQuick

import qs.modules.wallpaper

PanelWindow {
    id: root

    aboveWindows: false
    color: "transparent"

    anchors {
        top: true
        right: true
        left: true
        bottom: true
    }

    WallpaperDropArea {
        screen: root.screen
    }
}
