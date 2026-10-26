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

    // Stay mapped while a panel folds back into the bar.
    visible: (OverlayService.currentPanel !== "" && OverlayService.currentPanel !== "launcher") || popupContent.anyPanelVisible
    color: "transparent"

    aboveWindows: true
    focusable: true

    // Leave the top bar out of the input region, so one click on another bar
    // button switches panels instead of only closing the open one.
    mask: Region {
        item: inputArea
    }

    Item {
        id: inputArea
        anchors.fill: parent
        anchors.topMargin: Theme.barSize
    }

    MouseArea {
        anchors.fill: parent
        // This is only the backdrop click target; keep panel content above it.
        z: -1
        onPressed: OverlayService.closeCurrentPanel()
    }

    Item {
        id: popupContent
        anchors.fill: parent
        focus: OverlayService.currentPanel !== "" && OverlayService.currentPanel !== "launcher"

        readonly property bool anyPanelVisible: {
            for (const child of children) {
                if (child.shown) return true;
            }
            return false;
        }

        Keys.onEscapePressed: OverlayService.closeOrGoBack()

        ControlCenterPopup {
            screenName: overlayLayer.screenName
            targetX: parent.width - width - 5
        }

        // The dashboard and the settings open in the same place, so they share
        // one panel. Both use the dashboard width, so switching only morphs the height.
        SendaPanel {
            id: centerPanel
            names: ["dashboard", "settings"]
            screenName: overlayLayer.screenName

            readonly property bool showSettings: activeName === "settings"
            readonly property var activeContent: showSettings ? settings : dashboard

            targetWidth: dashboard.contentWidth + 2 * padding
            targetHeight: activeContent.contentHeight
            targetX: parent.width / 2 - width / 2

            DashboardPanel {
                id: dashboard
                // Fixed size, so it is not squashed while the panel morphs.
                width: contentWidth
                height: contentHeight
                opacity: centerPanel.showSettings ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: centerPanel.animationDuration / 2 }
                }
            }

            SettingsPanel {
                id: settings
                // Fixed size, so it is not squashed while the panel morphs.
                width: dashboard.contentWidth
                height: contentHeight
                opacity: centerPanel.showSettings ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: centerPanel.animationDuration / 2 }
                }
            }
        }

        TasksPanel {
            screenName: overlayLayer.screenName
        }
        NotificationsPanel {
            screenName: overlayLayer.screenName
        }
    }

}
