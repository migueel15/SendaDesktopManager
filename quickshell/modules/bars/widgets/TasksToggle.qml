import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

Item {
	id: root

	// Name of the monitor the bar sits on; panels open there.
	property string screenName: ""

	readonly property bool open: OverlayService.isOpen("tasks")
	readonly property bool hasTask: DorlabTasks.hasTrackedTask

	height: parent.height
	implicitWidth: Math.min(container.implicitWidth, 520)

	component InlineAction: Rectangle {
		id: action

		property string icon: ""
		property color accent: Theme.colors.primary
		property bool available: true
		property bool busy: false

		signal clicked

		Layout.preferredWidth: 24
		Layout.preferredHeight: 24
		radius: Theme.rounding.full
		color: actionMouseArea.containsMouse && action.available ? action.accent : Theme.colors.surfaceVariant
		opacity: action.available || action.busy ? 1 : 0.45

		Text {
			anchors.centerIn: parent
			anchors.horizontalCenterOffset: !action.busy && action.icon === "󰐊" ? 1 : 0
			text: action.busy ? "󰔟" : action.icon
			color: actionMouseArea.containsMouse && action.available ? Theme.colors.background : action.accent
			font: Theme.font.icon
		}

		MouseArea {
			id: actionMouseArea
			anchors.fill: parent
			hoverEnabled: true
			enabled: action.available
			cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
			onClicked: action.clicked()
		}
	}

	Rectangle {
		id: container

		anchors.centerIn: parent
		// Without a task it is an icon-only button, sized like the others.
		implicitWidth: root.hasTask ? content.implicitWidth + 16 : Theme.barButtonSize
		height: Theme.barButtonSize
		radius: Theme.rounding.normal
		// Same hover pill as the tray button; stays lit while the panel is open.
		color: containerMouseArea.containsMouse || root.open ? Theme.colors.surfaceVariant : "transparent"

		Behavior on color {
			ColorAnimation {
				duration: 150
			}
		}

		MouseArea {
			id: containerMouseArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: OverlayService.togglePanel("tasks", root.screenName)
		}

		RowLayout {
			id: content

			anchors.fill: parent
			anchors.leftMargin: 8
			anchors.rightMargin: 8
			spacing: 8

			Item {
				Layout.preferredWidth: root.hasTask ? 24 : Theme.barButtonSize - 16
				Layout.fillHeight: true

				Text {
					anchors.centerIn: parent
					text: "󰄭"
					color: Theme.colors.text
					font: Theme.font.base
				}
			}

			Rectangle {
				Layout.preferredWidth: 1
				Layout.preferredHeight: 18
				visible: root.hasTask
				color: Theme.colors.overlay
				opacity: 0.45
			}

			Text {
				Layout.maximumWidth: 220
				visible: root.hasTask
				text: DorlabTasks.trackedTaskTitle
				color: Theme.colors.text
				font: Theme.font.overlay
				elide: Text.ElideRight
			}

			Text {
				visible: root.hasTask
				text: DorlabTasks.hasActiveTask ? DorlabTasks.formatDuration(DorlabTasks.activeElapsedSeconds) : "Pausada"
				color: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.warning
				font: Theme.font.overlay
			}

			InlineAction {
				visible: root.hasTask
				icon: DorlabTasks.hasActiveTask ? "󰏤" : "󰐊"
				accent: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.warning
				busy: DorlabTasks.actionInProgress
				available: !DorlabTasks.mutationInProgress
				onClicked: {
					if (DorlabTasks.hasActiveTask) {
						DorlabTasks.pauseActiveTask();
					} else {
						DorlabTasks.resumeLastTrackedTask();
					}
				}
			}

			InlineAction {
				visible: root.hasTask
				icon: ""
				accent: Theme.colors.error
				busy: DorlabTasks.actionInProgress
				available: !DorlabTasks.mutationInProgress
				onClicked: DorlabTasks.stopTracking(DorlabTasks.trackedTaskId, DorlabTasks.trackedTeamId)
			}
		}
	}
}
