import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import qs.common

Rectangle {
	id: workspaceRectangle
	color: "transparent"

	// Guards para evitar null access
	property var screenMonitor: Hyprland.monitorFor(topbar.screen)
	// Dots: empty ones in Humo, ones with windows in Hielo, and the active one
	// stretched into a Nieve pill. Width and color animate on change.
	// Sized from the bar font so they follow the text scale.
	readonly property int dotSize: Math.round(Theme.font.base.pixelSize * 0.65)
	readonly property int activeWidth: Math.round(Theme.font.base.pixelSize * 1.6)
	readonly property int dotGap: Math.round(Theme.font.base.pixelSize * 0.55)
	// property var workspacesNumber: Hyprland.workspaces.values?.length ?? 0
	// property var monitorNumber: Hyprland.monitors.values?.length ?? 1
	// property var workspacesPerScreen: monitorNumber > 0 ? workspacesNumber / monitorNumber : 0

	property var filteredWorkspaces: {
		if (!screenMonitor || !screenMonitor.name)
		return [];

		const workspaces = Hyprland.workspaces.values;
		if (!workspaces)
		return [];

		const filtered = workspaces.filter(ws => {
				return ws.monitor && ws.monitor.name === screenMonitor.name && !ws.name.startsWith("special:");
		});
		return filtered;
	}

	property var focusedMonitorWorkspace: screenMonitor?.activeWorkspace?.id ?? -1

	// Solo mostrar cuando los datos estén listos
	visible: screenMonitor !== null && filteredWorkspaces.length > 0
	implicitWidth: dotsRow.implicitWidth + dotGap * 2
	Layout.fillHeight: true

	Row {
		id: dotsRow
		anchors.centerIn: parent
		spacing: workspaceRectangle.dotGap

		Repeater {
			model: workspaceRectangle.filteredWorkspaces

			delegate: Item {
				id: cell

				required property var modelData
				readonly property bool isActive: modelData?.active ?? false
				readonly property bool hasClients: (modelData?.toplevels?.values?.length ?? 0) > 0

				width: dot.width
				height: workspaceRectangle.height

				Rectangle {
					id: dot
					anchors.verticalCenter: parent.verticalCenter
					width: cell.isActive ? workspaceRectangle.activeWidth : workspaceRectangle.dotSize
					height: workspaceRectangle.dotSize
					radius: Theme.rounding.full
					color: cell.isActive ? Theme.workspaces.activeWorkspaceColor
						: (cell.hasClients ? Theme.workspaces.notFocusedWorkspaceColor : Theme.workspaces.emptyWorkspaceColor)
					scale: hoverArea.containsMouse && !cell.isActive ? 1.25 : 1

					Behavior on width {
						NumberAnimation {
							duration: 260
							easing.type: Easing.OutCubic
						}
					}
					Behavior on color {
						ColorAnimation {
							duration: 200
						}
					}
					Behavior on scale {
						NumberAnimation {
							duration: 120
						}
					}
				}

				// Wider than the dot so small targets are easy to hit.
				MouseArea {
					id: hoverArea
					anchors.fill: parent
					anchors.leftMargin: -workspaceRectangle.dotGap / 2
					anchors.rightMargin: -workspaceRectangle.dotGap / 2
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						if (cell.modelData && cell.modelData.activate)
							cell.modelData.activate();
					}
				}
			}
		}
	}
}
