pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history for the launcher and the settings, through `senda clipboard`.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"
    property var entries: []

    function refresh() {
        if (!listProcess.running) listProcess.running = true;
    }
    function restore(id) {
        Quickshell.execDetached([root.binaryPath, "clipboard", "restore", id]);
    }
    function clear() {
        if (!clearProcess.running) clearProcess.running = true;
    }

    Process {
        id: listProcess
        command: [root.binaryPath, "clipboard", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.entries = JSON.parse(text); } catch (e) { console.warn("Portapapeles:", e); } }
        }
    }
    Process {
        id: clearProcess
        command: [root.binaryPath, "clipboard", "clear"]
        onExited: root.refresh()
    }
}
