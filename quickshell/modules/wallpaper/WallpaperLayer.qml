import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.modules.wallpaper

//
// Variants {
//     id: root
//     model: Quickshell.screens
//
//     required property var panelController
//
//     delegate: PanelWindow {
//         id: topbar
//
//         required property var modelData

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

        WallpaperDropArea {
            screen: wallpaperLayer.screen
        }
    }
}
