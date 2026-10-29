import QtQuick
import Quickshell
import qs.common
import qs.common.components
import qs.services
import qs.modules.panels.ControlCenter
import qs.modules.panels.Dashboard
import qs.modules.panels.Tasks
import qs.modules.panels.notifications
import qs.modules.launcher
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

    // Respect reserved desktop areas, while extending back over the top bar.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    margins.top: -Theme.barSize

    // Map only after currentPanelUpdated, once keyboardFocus below already has
    // its final value: a layer mapped with OnDemand and switched to Exclusive
    // afterwards does not get the keyboard until the pointer moves over it.
    property bool panelRequested: false
    Connections {
        target: OverlayService
        function onCurrentPanelUpdated() { overlayLayer.panelRequested = OverlayService.currentPanel !== ""; }
    }

    // Stay mapped while a panel folds back into the bar.
    visible: panelRequested || popupContent.anyPanelVisible
    color: "transparent"

    aboveWindows: true
    // On-demand focus follows the pointer, so the launcher takes the keyboard
    // exclusively wherever the mouse is. Backdrops on other monitors never
    // compete for it.
    readonly property bool onCurrentScreen: OverlayService.currentScreen === screenName
    WlrLayershell.keyboardFocus: !onCurrentScreen && OverlayService.currentPanel !== ""
        ? WlrKeyboardFocus.None
        : onCurrentScreen && OverlayService.currentPanel === "launcher"
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.OnDemand

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
        focus: OverlayService.currentPanel !== ""

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

        SendaPanel {
            names: ["dashboard"]
            screenName: overlayLayer.screenName

            targetWidth: dashboard.contentWidth + 2 * padding
            targetHeight: dashboard.contentHeight
            targetX: parent.width / 2 - width / 2

            DashboardPanel {
                id: dashboard
                // Fixed size, so it is not squashed while the panel morphs.
                width: contentWidth
                height: contentHeight
            }
        }

        TasksPanel {
            screenName: overlayLayer.screenName
        }
        NotificationsPanel {
            screenName: overlayLayer.screenName
        }
        LauncherPanel {
            screenName: overlayLayer.screenName
        }
    }

}
