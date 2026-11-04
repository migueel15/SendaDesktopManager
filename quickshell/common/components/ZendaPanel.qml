import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.common
import qs.common.components.barextension
import qs.services

// Overlay panel that unfolds downwards from the top bar, like the bar extensions.
// One panel can host several panel names (see `names`); switching between them
// morphs the same shape to the new size instead of folding and unfolding.
Item {
    id: root

    property string name: ""
    // Panel names shown by this panel. Defaults to `name`.
    property var names: name ? [name] : []

    property var targetX
    property var targetY

    // Width of the panel body including padding, and height of the content.
    property var targetWidth
    property var targetHeight

    property int padding: 16
    // Duration of height changes while open; see BarExtension.resizeDuration.
    property int resizeDuration: 310

    default property alias content: contentItem.data

    // Name of the monitor this panel is drawn on. Set by the overlay that hosts it.
    property string screenName: ""
    // True on the monitor the panel was opened from.
    readonly property bool onOpenScreen: root.screenName !== "" && root.screenName === OverlayService.currentScreen

    readonly property bool open: root.names.indexOf(OverlayService.currentPanel) !== -1 && root.onOpenScreen
        || Debug.enabled && root.names.indexOf(Debug.panel) !== -1
    // Last name shown, kept while the panel folds back into the bar.
    property string activeName: root.names.length > 0 ? root.names[0] : ""

    readonly property int animationDuration: 310

    function updateActiveName() {
        if (!root.open) return;
        const current = root.names.indexOf(OverlayService.currentPanel) !== -1 ? OverlayService.currentPanel : Debug.panel;
        if (current) root.activeName = current;
    }

    onOpenChanged: {
        updateActiveName();
        // Fullscreen modes are only known from the toplevels' IPC data.
        if (root.open) Hyprland.refreshToplevels();
    }

    // A fullscreen window covers the bar, so the panel does not join it.
    // Maximized windows (mode 1) keep the bar visible; while the mode is
    // unknown, any fullscreen window counts as covering it.
    readonly property var hyprWorkspace: Hyprland.monitors.values.find(m => m.name === root.screenName)?.activeWorkspace ?? null
    readonly property bool barCovered: {
        const workspace = root.hyprWorkspace;
        if (!workspace?.hasFullscreen) return false;
        const modes = workspace.toplevels.values
            .map(t => t.lastIpcObject?.fullscreen)
            .filter(mode => mode !== undefined);
        return modes.length === 0 || modes.some(mode => mode === 2);
    }
    Connections {
        target: OverlayService
        function onCurrentPanelUpdated() {
            root.updateActiveName();
        }
    }

    // The curve width is fixed so it does not depend on the panel width.
    readonly property real curveWidth: Theme.barBorderRadius

    x: targetX ?? 0
    y: targetY ?? Theme.barSize

    width: (targetWidth ?? 0) + 2 * curveWidth
    height: extension.height
    // True while open or folding back into the bar.
    readonly property bool shown: root.open || extension.height > 0.01
    visible: shown

    // Morph between sizes only while open; the first unfold keeps the bar animation.
    Behavior on width {
        enabled: extension.expanded && extension.height > 0.01
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    // Keep clicks on the panel from reaching the overlay backdrop.
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: mouse => mouse.accepted = true
    }

    // The shadow stops at the bottom edge of the bar, as in the bar's popup
    // windows, which start below the bar: this layer also covers the bar, and
    // an unclipped shadow would darken its edge.
    Item {
        id: shadowClip
        clip: true
        x: -extension.shadowSpace
        width: parent.width + 2 * extension.shadowSpace
        height: parent.height + extension.shadowSpace

        BarExtension {
            id: extension
            x: extension.shadowSpace
            width: root.width
            cornerRadius: root.curveWidth
            attachedToBar: !root.barCovered
            expanded: root.open
            expandedHeight: (root.targetHeight ?? 0) + 2 * root.padding
            autoHideOnPointerExit: false
            resizeDuration: root.resizeDuration

            Item {
                id: contentItem
                // Fixed size, so the content is revealed instead of squashed while unfolding.
                x: root.padding
                y: root.padding
                width: Math.max(0, (root.targetWidth ?? 0) - 2 * root.padding)
                height: root.targetHeight ?? 0
            }
        }
    }
}
