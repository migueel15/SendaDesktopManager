import Quickshell
import QtQuick.Layouts
import QtQuick

import qs.common
import qs.services
import qs.modules.bars.widgets
import Quickshell.Io
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    required property var panelController

    delegate: PanelWindow {
        id: topbar

        WlrLayershell.namespace: "Senda:TopBar"

        required property var modelData
        screen: modelData

        property var panelController: root.panelController

        exclusionMode: ExclusionMode.Auto

        focusable: false
        aboveWindows: true

        color: Theme.colors.background

        anchors {
            top: true
            left: true
            right: true
            // bottom: true
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
                    OverlayService.setCurrentPanel("controlCenter");
                }
                Layout.rightMargin: 8
                Layout.leftMargin: 8
            }
        }
    }
}
