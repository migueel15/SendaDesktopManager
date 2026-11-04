import QtQuick
import Quickshell

import qs.common
import qs.services
import "../../../common/components/lazy/lifetime.js" as Lifetime

// Standalone settings window. Its title matches the Hyprland rule in Zenda's
// module, which opens it floating and centred on the focused monitor.
FloatingWindow {
    id: root

    visible: ZendaSettings.windowOpen
    title: "Ajustes de Zenda"
    // A share of the monitor it opens on, never smaller than the minimum the
    // pages are laid out for nor larger than the monitor.
    readonly property var targetScreen: ZendaSettings.windowScreen
    implicitWidth: targetScreen
        ? Math.min(targetScreen.width * 0.9, Math.max(Theme.scaled(820), targetScreen.width * 0.6))
        : Theme.scaled(1040)
    implicitHeight: targetScreen
        ? Math.min(targetScreen.height * 0.9, Math.max(Theme.scaled(560), targetScreen.height * 0.7))
        : Theme.scaled(720)
    color: Theme.colors.background

    // Closing from the window manager only updates the service state.
    onClosed: ZendaSettings.closeWindow()

    Shortcut {
        sequence: "Escape"
        onActivated: ZendaSettings.closeWindow()
    }

    Loader {
        anchors.fill: parent
        anchors.margins: Theme.spacing.md
        active: ZendaSettings.windowOpen || Lifetime.hasDraft(item)
        sourceComponent: Component { SettingsPanel {} }
        }
    }
