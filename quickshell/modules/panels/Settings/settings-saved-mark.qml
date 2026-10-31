import QtQuick
import qs.common
import qs.services

// Check mark that fades in and out when its setting is saved. It always takes
// its space, so the row does not move.
Text {
    id: mark
    property string flag: ""
    text: ""
    color: Theme.colors.success
    font.family: Theme.iconFamily
    font.pixelSize: Theme.scaled(13)
    opacity: 0
    Accessible.ignored: true
    Connections {
        target: SendaHyprlandSettings
        function onSaved(flag) { if (flag === mark.flag) pulse.restart(); }
    }
    SequentialAnimation {
        id: pulse
        NumberAnimation { target: mark; property: "opacity"; to: 1; duration: 120 }
        PauseAnimation { duration: 900 }
        NumberAnimation { target: mark; property: "opacity"; to: 0; duration: 400 }
    }
}
