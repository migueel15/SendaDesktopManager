import Quickshell
import QtQuick
import qs.common

import qs.modules.panels.Dashboard
import qs.modules.panels.ControlCenter

FloatingWindow {
    id: root
    property string screenName: Debug.debugScreenName
    default property alias content: root.data

    screen: Quickshell.screens.find(s => s.name === root.screenName)

    color: "transparent"
    visible: Debug.enabled

    DashboardPanel {}
}
