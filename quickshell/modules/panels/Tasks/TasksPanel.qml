import qs.common.components
import QtQuick
import qs.modules.panels.Tasks

SendaPanel {
    id: root
    name: "tasks"

    padding: 12
    targetWidth: 560
    targetHeight: parent.height - 90

    targetX: 8
    targetY: 50

    TasksSidebarView {
        anchors.fill: parent
    }
}
