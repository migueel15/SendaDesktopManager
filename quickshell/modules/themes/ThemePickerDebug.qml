import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.common

// Debug-only window that keeps the theme picker open under the bar, without
// the full-screen backdrop or exclusive keyboard focus of the real one, so it
// can stay on screen while its design changes. Enable it with
// Debug.enabled and Debug.panel = "themes".
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Debug.debugScreenName) ?? Quickshell.screens[0]
    WlrLayershell.namespace: "Zenda:ThemePickerDebug"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true
    margins.top: Theme.barSize
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    implicitWidth: picker.width
    implicitHeight: picker.expandedHeight + picker.shadowSpace

    ThemePicker {
        id: picker
        width: Theme.scaled(760)
        onPickerScreen: true
        expanded: true
        onCloseRequested: {}
    }
}
