import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.common
import qs.modules.panels.ControlCenter
import qs.modules.panels.Dashboard

PanelWindow {
    id: root

    property string screenName: Debug.debugScreenName

    WlrLayershell.namespace: "Senda:DebugLayer"

    screen: Quickshell.screens.find(s => s.name === root.screenName)

    anchors {
        top: true
        right: true
    }

    margins.top: 45
    margins.right: 5

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    color: "transparent"
    visible: Debug.enabled && (Debug.panel === "controlCenter" || Debug.panel === "dashboard")

    implicitWidth: Debug.panel === "dashboard" ? 700 : 500
    implicitHeight: Debug.panel === "dashboard" ? 480 : controlCenter.height

    DashboardPanel {
        targetX: 0
        targetY: 0
    }

    ControlCenterPopup {
        id: controlCenter
        targetX: 0
        targetY: 0
    }
}
