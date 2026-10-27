import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

import qs.common
import qs.services

// Power menu, attached under the user card like the other selectors.
DropdownCard {
    id: systemMenu

    property bool isOpen: false

    expanded: isOpen
    contentHeight: contentColumn.implicitHeight + 20

    // Processes for system actions

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
        anchors.fill: parent
        anchors.margins: 10
        spacing: 3

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
                LockService.lock();
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
