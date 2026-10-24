import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.modules.wallpaper

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: wallpaperLayer

        WlrLayershell.namespace: "Senda:Static:WallpaperLayer"

        required property var modelData
        screen: modelData

        aboveWindows: false
        color: "transparent"

        anchors {
            top: true
            right: true
            left: true
            bottom: true
        }

        WallpaperView {
            anchors.fill: parent
            screenName: wallpaperLayer.screen.name
        }

        WallpaperDropArea {
            screen: wallpaperLayer.screen
        }
    }
}
