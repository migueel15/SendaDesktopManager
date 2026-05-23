import Quickshell
import QtQuick.Layouts
import QtQuick

import qs.common
import qs.common.widgets
import qs.common.popups.ControlCenter
import Quickshell.Io

PanelWindow {
    id: topbar

    property var popupController: null

    exclusionMode: ExclusionMode.Auto

    focusable: false
    aboveWindows: true

    color: Theme.colors.background
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barSize

    Process {
        id: reloadProc
        running: false
		command: ["bash", Qt.resolvedUrl("../../utils/reloadHyprland.sh").toString().replace("file://", "")]

		onRunningChanged: {
			if (!running) {
				// Process finished, reset state
				reloadProc.running = false;
			}
		}
    }

    RowLayout {
        height: parent.height
        spacing: 15
        Text {
            color: Theme.colors.primary
            leftPadding: 15
            text: "󰣇"
            font: Theme.font.base

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    reloadProc.running = true;
                }
            }
        }
        Workspaces {}
    }

    Clock {}

    RowLayout {
        spacing: 0
        height: parent.height
        anchors.right: parent.right

        NowPlaying {
            Layout.rightMargin: 8
            Layout.leftMargin: 8
        }

        SystemTray {
            Layout.rightMargin: 8
            Layout.leftMargin: 8
        }

        Notifications {}

        ControlPanel {
            onClicked: {
                if (popupController) {
                    popupController.toggleControlCenter(topbar.width - 500 - 5, topbar.height + 5);
                }
            }
            Layout.rightMargin: 8
            Layout.leftMargin: 8
        }
    }
}
