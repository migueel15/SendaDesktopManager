import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.common
import qs.common.components.icons

Item {
    id: root
    property var icon: null
    property var label: null
    property var color: null
    property var font: Theme.font.base

    height: parent.height
    implicitWidth: rowLayout.implicitWidth

    Rectangle {
        id: background
        height: parent.height
        implicitWidth: rowLayout.implicitWidth
        color: "transparent"

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 2
            ZendaIcon {
                visible: root.icon !== null
                text: root.icon
                color: root.color
            }

            Text {
                visible: root.label !== null
                text: root.label
                color: root.color
                font: root.font
            }
        }
    }
}
