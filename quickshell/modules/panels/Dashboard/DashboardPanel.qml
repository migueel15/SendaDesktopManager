import qs.common.components
import QtQuick
import qs.modules.panels.Dashboard

SendaPanel {
    id: root
    name: "dashboard"

    targetWidth: 700
    targetHeight: 480

    targetX: parent.width / 2 - root.width / 2
    targetY: 45

    ClockCard {}
}
