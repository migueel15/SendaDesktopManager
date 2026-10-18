import qs.common
import qs.common.components
import QtQuick
import qs.modules.panels.Tasks

SendaPanel {
    id: root
    name: "tasks"

    padding: 12
    targetWidth: 560
    targetHeight: parent.height - Theme.barSize - 50

    targetX: 8

    TasksSidebarView {
        anchors.fill: parent
    }
}
