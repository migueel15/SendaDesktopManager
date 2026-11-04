pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool enabled: true
    property string debugScreenName: "DP-4"
    property string panel: "controlCenter"
    // Opens the design gallery window (DesignGallery.qml).
    property bool gallery: true
}
