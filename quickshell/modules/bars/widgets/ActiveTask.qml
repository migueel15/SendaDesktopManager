import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.components.icons
import qs.common.components.controls
import qs.services

Rectangle {
    id: root

    readonly property bool hasTask: DorlabTasks.hasTrackedTask

    visible: hasTask
    implicitWidth: hasTask ? Math.min(content.implicitWidth + 18, 420) : 0
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
            text: DorlabTasks.trackedTaskTitle
            color: Theme.colors.text
            font: Theme.font.overlay
            elide: Text.ElideRight
        }

        Text {
            text: DorlabTasks.hasActiveTask ? DorlabTasks.formatDuration(DorlabTasks.activeElapsedSeconds) : "Pausada"
            color: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.warning
            font: Theme.font.overlay
        }

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: Theme.rounding.full
            color: Theme.colors.surfaceVariant
            ZendaStateLayer { hovered: mainActionMouseArea.containsMouse && mainActionMouseArea.enabled; pressed: mainActionMouseArea.pressed }
            opacity: DorlabTasks.actionInProgress ? 0.5 : 1

            ZendaIcon {
                anchors.centerIn: parent
                text: DorlabTasks.actionInProgress ? "󰔟" : DorlabTasks.hasActiveTask ? "󰏤" : "󰐊"
                color: Theme.colors.text
            }

            MouseArea {
                id: mainActionMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !DorlabTasks.mutationInProgress
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (DorlabTasks.hasActiveTask) {
                        DorlabTasks.pauseActiveTask();
                    } else {
                        DorlabTasks.resumeLastTrackedTask();
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: Theme.rounding.full
            color: Theme.colors.surfaceVariant
            ZendaStateLayer { hovered: stopMouseArea.containsMouse && stopMouseArea.enabled; pressed: stopMouseArea.pressed; color: Theme.colors.error }
            opacity: DorlabTasks.actionInProgress ? 0.5 : 1

            ZendaIcon {
                anchors.centerIn: parent
                text: DorlabTasks.actionInProgress ? "󰔟" : ""
                color: Theme.colors.text
            }

            MouseArea {
                id: stopMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !DorlabTasks.mutationInProgress
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: DorlabTasks.stopTracking(DorlabTasks.trackedTaskId, DorlabTasks.trackedTeamId)
            }
        }
    }
}
