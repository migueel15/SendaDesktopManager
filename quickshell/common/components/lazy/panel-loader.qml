import QtQuick
import qs.common
import qs.services
import "lifetime.js" as Lifetime

// Load only on the requested monitor. Keep the outgoing panel through its
// actual closing animation, and retain input that cannot be reconstructed.
Loader {
    id: root
    property var panelNames: []
    property string screenName: ""
    readonly property bool requested: (screenName === OverlayService.currentScreen
        && panelNames.includes(OverlayService.currentPanel))
        || (Debug.enabled && panelNames.includes(Debug.panel))
    readonly property bool shown: item?.shown ?? false
    readonly property bool retained: Lifetime.hasDraft(item)
    anchors.fill: parent
    active: requested || shown || retained
}
