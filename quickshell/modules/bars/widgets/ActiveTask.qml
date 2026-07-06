import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

Rectangle {
    id: root

    readonly property bool hasTask: DorlabTasks.hasActiveTask

    visible: hasTask
    implicitWidth: hasTask ? Math.min(content.implicitWidth + 18, 360) : 0
    height: parent.height * 0.8
    radius: Theme.rounding.full
    color: Theme.colors.surface
    border.width: 1
    border.color: Theme.colors.surfaceVariant

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 9
        anchors.rightMargin: 7
        spacing: 8

        Text {
            Layout.maximumWidth: 220
            text: DorlabTasks.activeTask?.title ?? ""
            color: Theme.colors.text
            font: Theme.font.overlay
            elide: Text.ElideRight
        }

        Text {
            text: DorlabTasks.formatDuration(DorlabTasks.activeElapsedSeconds)
            color: Theme.colors.primary
            font: Theme.font.overlay
        }

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: Theme.rounding.full
            color: pauseMouseArea.containsMouse && pauseMouseArea.enabled ? Theme.colors.primary : Theme.colors.surfaceVariant
            opacity: DorlabTasks.actionInProgress ? 0.5 : 1

            Text {
                anchors.centerIn: parent
                text: DorlabTasks.actionInProgress ? "󰔟" : "󰏤"
                color: pauseMouseArea.containsMouse && pauseMouseArea.enabled ? Theme.colors.background : Theme.colors.text
                font: Theme.font.icon
            }

            MouseArea {
                id: pauseMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !DorlabTasks.actionInProgress
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: DorlabTasks.pauseActiveTask()
            }
        }
    }
}
