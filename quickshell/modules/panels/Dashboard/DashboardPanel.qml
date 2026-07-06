import qs.common.components
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.modules.panels.Dashboard

SendaPanel {
    id: root
    name: "dashboard"

    property int activeTab: 0
    readonly property var tabs: ["Dashboard", "Tasks"]

    targetWidth: 700
    targetHeight: 480

    targetX: parent.width / 2 - root.width / 2
    targetY: 45

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.tabs

                delegate: Rectangle {
                    id: tabButton

                    required property int index
                    required property string modelData

                    readonly property bool selected: root.activeTab === index

                    Layout.preferredWidth: tabText.implicitWidth + 24
                    Layout.preferredHeight: 34
                    radius: Theme.rounding.full
                    color: selected || tabMouseArea.containsMouse ? Theme.colors.surfaceVariant : Theme.colors.surface
                    border.width: 1
                    border.color: selected ? Theme.colors.primary : Theme.colors.surfaceVariant

                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: tabButton.modelData
                        color: tabButton.selected ? Theme.colors.primary : Theme.colors.text
                        font: Theme.font.overlay
                    }

                    MouseArea {
                        id: tabMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = tabButton.index
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                anchors.fill: parent
                visible: root.activeTab === 0

                ClockCard {
                    anchors.left: parent.left
                    anchors.top: parent.top
                }
            }

            TasksView {
                anchors.fill: parent
                visible: root.activeTab === 1
            }
        }
    }
}
