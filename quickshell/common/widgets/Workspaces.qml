import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import qs.common

Rectangle {
    id: workspaceRectangle
    color: Theme.colors.background

    // Guards para evitar null access
    property var screenMonitor: Hyprland.monitorFor(topbar.screen)
    property var workspacesNumber: Hyprland.workspaces.values?.length ?? 0
    property var monitorNumber: Hyprland.monitors.values?.length ?? 1
    property var workspacesPerScreen: monitorNumber > 0 ? workspacesNumber / monitorNumber : 0

    property var filteredWorkspaces: {
        if (!screenMonitor || !screenMonitor.name)
            return [];

        const workspaces = Hyprland.workspaces.values;
        if (!workspaces)
            return [];

        const filtered = workspaces.filter(ws => {
            return ws.monitor && ws.monitor.name === screenMonitor.name;
        });
        return filtered;
    }

    property var focusedMonitorWorkspace: screenMonitor?.activeWorkspace?.id ?? -1

    // Solo mostrar cuando los datos estén listos
    visible: screenMonitor !== null && filteredWorkspaces.length > 0

    height: parent.height
    width: workspacesPerScreen * (Theme.workspaces.font.pixelSize + (Theme.workspaces.spacing * 2))

    RowLayout {
        anchors.top: parent.top
        spacing: 0

        Repeater {
            model: workspaceRectangle.filteredWorkspaces

            delegate: Rectangle {
                color: "transparent"
                width: workspaceRectangle.width / Math.max(workspaceRectangle.workspacesPerScreen, 1)
                height: workspaceRectangle.height

                property var workspace: modelData
                property bool isActive: workspace?.active ?? false
                property bool hasClients: workspace?.toplevels?.values?.length > 0 ?? false

                Text {
                    anchors.centerIn: parent
                    color: isActive ? Theme.workspaces.activeWorkspaceColor : (hasClients ? Theme.workspaces.notFocusedWorkspaceColor : Theme.workspaces.emptyWorkspaceColor)
                    text: Theme.workspaces.icon
                    font: Theme.workspaces.font
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (workspace && workspace.activate) {
                            workspace.activate();
                        }
                    }
                }
            }
        }
    }
}
