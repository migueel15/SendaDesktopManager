// topbar/Corners.qml

import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.common
import qs.common.components

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: topLeftCorner

        required property var modelData
        screen: modelData

        focusable: false
        aboveWindows: true

        WlrLayershell.namespace: "Senda:EdgeCorner"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Auto

        mask: Region {}

        color: "transparent"

        anchors {
            // right: true
            top: true
            // bottom: true
            left: true
        }

        BarCorner {
            id: topLeftBarCorner
            anchors {
                top: parent.top
                left: parent.left
            }
            position: "top-left"
        }
    }
}
