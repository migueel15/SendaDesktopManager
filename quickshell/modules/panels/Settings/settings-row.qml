import QtQuick
import QtQuick.Layouts
import qs.common

Item {
    id: root
    property string label: ""
    property string description: ""
    property bool separator: true
    default property alias controls: controlLayout.data
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + (separator ? Theme.spacing.md + 1 : 0)
    Rectangle {
        width: parent.width
        height: 1
        visible: root.separator
        color: Theme.colors.border
    }
    // Controls are anchored to the right edge so every row lines them up,
    // whatever the length of its label.
    Item {
        id: content
        width: root.width
        y: root.separator ? Theme.spacing.md + 1 : 0
        implicitHeight: Math.max(textColumn.implicitHeight, controlLayout.implicitHeight)
        ColumnLayout {
            id: textColumn
            anchors.left: parent.left
            anchors.right: controlLayout.left
            anchors.rightMargin: controlLayout.width > 0 ? Theme.spacing.md : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xs
            Text {
                Layout.fillWidth: true
                text: root.label
                color: Theme.colors.text
                font: Theme.font.body
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.description
                color: Theme.colors.overlay
                font: Theme.font.caption
                wrapMode: Text.WordWrap
            }
        }
        RowLayout {
            id: controlLayout
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width * 0.6)
            spacing: Theme.spacing.sm
        }
    }
}
