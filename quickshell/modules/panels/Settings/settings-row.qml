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
    RowLayout {
        id: content
        width: root.width
        y: root.separator ? Theme.spacing.md + 1 : 0
        spacing: Theme.spacing.md
        ColumnLayout {
            implicitWidth: 0
            Layout.fillWidth: true
            Layout.minimumWidth: 0
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
            Layout.maximumWidth: root.width * 0.6
            spacing: Theme.spacing.sm
        }
    }
}
