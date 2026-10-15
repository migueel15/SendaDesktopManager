pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool dndEnabled: false
    property bool hasNotifications: false
    property bool requestedDndEnabled: false
    property bool dndCommandPending: false

    signal dndChanged(bool enabled)

    Component.onCompleted: root.refreshDnd()

    function updateDnd(enabled) {
        if ((root.dndCommandPending || dndToggleProcess.running)
                && enabled !== root.requestedDndEnabled) return;
        if (root.dndEnabled === enabled) return;
        root.dndEnabled = enabled;
        root.dndChanged(enabled);
    }

    function parseState(line) {
        try {
            const data = JSON.parse(line);
            switch (data.alt) {
            case "none":
                root.hasNotifications = false;
                root.updateDnd(false);
                break;
            case "notification":
                root.hasNotifications = true;
                root.updateDnd(false);
                break;
            case "dnd-none":
                root.hasNotifications = false;
                root.updateDnd(true);
                break;
            case "dnd-notification":
                root.hasNotifications = true;
                root.updateDnd(true);
                break;
            default:
                break;
            }
        } catch (e) {
            console.error("Error parsing SwayNC state:", e);
        }
    }

    function setDndEnabled(enabled) {
        root.requestedDndEnabled = enabled;
        root.dndCommandPending = true;
        root.updateDnd(enabled);
        root.runDndCommand();
    }

    function toggleDnd() {
        root.setDndEnabled(!root.dndEnabled);
    }

    function runDndCommand() {
        if (!root.dndCommandPending || dndToggleProcess.running) return;
        root.dndCommandPending = false;
        dndToggleProcess.command = ["swaync-client", root.requestedDndEnabled ? "-dn" : "-df"];
        dndToggleProcess.running = true;
    }

    function refreshDnd() {
        if (!dndStateProcess.running) dndStateProcess.running = true;
    }

    Process {
        id: swayncDaemon
        running: true
        command: ["swaync-client", "-swb"]

        stdout: SplitParser {
            onRead: line => root.parseState(line)
        }
    }

    Process {
        id: dndStateProcess
        running: false
        command: ["swaync-client", "-D"]

        stdout: StdioCollector {
            onStreamFinished: root.updateDnd(text.trim().toLowerCase() === "true")
        }
    }

    Process {
        id: dndToggleProcess
        running: false
        command: []

        onExited: {
            root.refreshDnd();
            root.runDndCommand();
        }
    }
}
