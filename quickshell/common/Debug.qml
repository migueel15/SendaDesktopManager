pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool enabled: false
    property string debugScreenName: "DP-3"

    property var debugedPanels: ["dashboard"]
}
