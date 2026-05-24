import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

import qs.common

Rectangle {
    id: systemMenu

    property bool isOpen: false

    width: 200
    height: isOpen ? contentColumn.implicitHeight : 0
    color: Theme.colors.surface
    radius: 8
    clip: true

    visible: height > 0

    Behavior on height {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // Processes for system actions
    Process {
        id: lockProcess
        running: false
        command: ["hyprlock"]
    }

    Process {
        id: logoutProcess
        running: false
        command: ["hyprctl", "dispatch", "hl.dsp.exit()"]
    }

    Process {
        id: suspendProcess
        running: false
        command: ["systemctl", "suspend"]
    }

    Process {
        id: rebootProcess
        running: false
        command: ["systemctl", "reboot"]
    }

    Process {
        id: poweroffProcess
        running: false
        command: ["systemctl", "poweroff"]
    }

    Column {
        id: contentColumn
        width: parent.width
        spacing: 0

        SystemMenuItem {
            icon: ""
            text: "Apagar"
            onClicked: {
                systemMenu.isOpen = false;
                poweroffProcess.running = true;
            }
        }

        SystemMenuItem {
            icon: "󰜉"
            text: "Reiniciar"
            onClicked: {
                systemMenu.isOpen = false;
                rebootProcess.running = true;
            }
        }

        SystemMenuItem {
            icon: "󰒲"
            text: "Suspender"
            onClicked: {
                systemMenu.isOpen = false;
                suspendProcess.running = true;
            }
        }

        SystemMenuItem {
            icon: ""
            text: "Bloquear"
            onClicked: {
                systemMenu.isOpen = false;
                lockProcess.running = true;
            }
        }

        SystemMenuItem {
            icon: ""
            text: "Cerrar sesión"
            onClicked: {
                systemMenu.isOpen = false;
                logoutProcess.running = true;
            }
        }
    }

    function toggle() {
        isOpen = !isOpen;
    }

    function close() {
        isOpen = false;
    }
}
