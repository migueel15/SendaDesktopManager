import QtQuick
import Quickshell
import qs.common
import qs.common.components
import qs.services
import qs.modules.panels.ControlCenter
import qs.modules.panels.Dashboard
import qs.modules.panels.Settings
import qs.modules.panels.Tasks
import qs.modules.panels.notifications
import Quickshell.Wayland

PanelWindow {
    id: overlayLayer

    // One layer per monitor, so a click on any monitor closes an open panel.
    // Panels themselves only show on the monitor they were opened from.
    required property var modelData
    screen: modelData
    readonly property string screenName: modelData.name

    WlrLayershell.namespace: "Senda:OverlayLayer"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore

    // visible: hasOpenPopup
    visible: OverlayService.currentPanel !== ""
    color: "transparent"

    aboveWindows: true
    focusable: true

    MouseArea {
        anchors.fill: parent
        // This is only the backdrop click target; keep panel content above it.
        z: -1
        onPressed: OverlayService.closeCurrentPanel()
    }

    Item {
        id: popupContent
        anchors.fill: parent
        focus: OverlayService.currentPanel !== ""

        Keys.onEscapePressed: OverlayService.closeCurrentPanel()

        ControlCenterPopup {
            screenName: overlayLayer.screenName
            targetX: parent.width - 500 - 5
            targetY: 45
        }

        DashboardPanel {
            id: dashboard
            screenName: overlayLayer.screenName
        }

        TasksPanel {
            screenName: overlayLayer.screenName
        }
        SettingsPanel {
            screenName: overlayLayer.screenName
        }
        NotificationsPanel {
            screenName: overlayLayer.screenName
        }
    }

}
