pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool enabled: true
    property string debugScreenName: "DP-4"
    // controlCenter, dashboard, themes or wallpapers.
    property string panel: "wallpapers"
}
