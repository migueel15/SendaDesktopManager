import QtQuick
import Quickshell

import qs.common
import qs.services

// Standalone settings window. Its title matches the Hyprland rule in Senda's
// module, which opens it floating and centred on the focused monitor.
FloatingWindow {
    id: root

    visible: SendaSettings.windowOpen
    title: "Ajustes de Senda"
    implicitWidth: Theme.scaled(820)
    implicitHeight: Theme.scaled(560)
    color: Theme.colors.background

    // Closing from the window manager only updates the service state.
    onClosed: SendaSettings.closeWindow()

    Shortcut {
        sequence: "Escape"
        onActivated: SendaSettings.closeWindow()
    }

    SettingsPanel {
        anchors.fill: parent
        anchors.margins: Theme.spacing.md
    }
}
