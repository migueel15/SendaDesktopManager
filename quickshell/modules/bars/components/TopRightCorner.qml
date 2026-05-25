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
        id: topRightCorner

        required property var modelData
        screen: modelData

        // implicitHeight: 39
        // implicitWidth: 39

        // exclusionMode: ExclusionMode.Overlay
        // WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Auto

        focusable: false
        aboveWindows: true

        WlrLayershell.namespace: "Senda:EdgeCorner"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        color: "transparent"

        anchors {
            right: true
            top: true
            // bottom: true
            // left: true
        }

        BarCorner {
            id: topRightBarCorner
            anchors {
                top: parent.top
                right: parent.right
            }
            position: "top-right"
        }
    }
}
