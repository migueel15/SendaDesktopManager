import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.common

Item {
    id: root
    property string label: ""
    property string description: ""
    property bool separator: true
    // The value differs from its default: shows the reset icon.
    property bool modified: false
    // Found by the settings search. Rows generated from data set it to false.
    property bool searchable: true
    // Scrolls the row into view inside its page and highlights it.
    function reveal() {
        let page = root.parent;
        while (page && page.contentY === undefined) page = page.parent;
        if (page) {
            const y = root.mapToItem(page.contentItem, 0, 0).y;
            page.contentY = Math.max(0, Math.min(y - Theme.spacing.md, page.contentHeight - page.height));
        }
        flash.restart();
    }
    signal resetRequested()
    default property alias controls: controlLayout.data
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + (separator ? Theme.spacing.md + 1 : 0)
    Rectangle {
        id: highlight
        anchors { fill: parent; margins: -Theme.spacing.xs }
        radius: Theme.rounding.small
        color: Theme.colors.selection
        opacity: 0
        SequentialAnimation {
            id: flash
            NumberAnimation { target: highlight; property: "opacity"; to: 1; duration: 150 }
            PauseAnimation { duration: 900 }
            NumberAnimation { target: highlight; property: "opacity"; to: 0; duration: 500 }
        }
    }
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
            anchors.right: resetButton.left
            anchors.rightMargin: controlLayout.width > 0 || root.modified ? Theme.spacing.md : 0
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
        Controls.AbstractButton {
            id: resetButton
            anchors.right: controlLayout.left
            anchors.rightMargin: root.modified ? Theme.spacing.sm : 0
            anchors.verticalCenter: parent.verticalCenter
            visible: root.modified
            width: visible ? Theme.scaled(22) : 0
            height: Theme.scaled(22)
            Accessible.name: "Restablecer " + root.label
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: "Restablecer"
            onClicked: root.resetRequested()
            contentItem: Text {
                text: "\uf0e2"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: resetButton.hovered ? Theme.colors.primary : Theme.colors.overlay
                font.family: Theme.iconFamily
                font.pixelSize: Theme.scaled(13)
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
