pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard, mouse and cursor settings, read and written through `senda input`.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"
    property var current: ({})
    // Only fields defined by the user's configuration appear here.
    property var user: ({})
    property var cursorThemes: []
    property string error: ""
    property var pending: []

    function refresh() {
        if (readProcess.running || writeProcess.running) return;
        // sync also picks up what the user changed in their configuration.
        readProcess.command = [root.binaryPath, "input", "sync", "--json"];
        readProcess.running = true;
    }

    function set(flag, value) {
        root.pending = root.pending.concat([[flag, String(value)]]);
        root.next();
    }

    function next() {
        if (writeProcess.running || root.pending.length === 0) return;
        const [flag, value] = root.pending[0];
        root.pending = root.pending.slice(1);
        writeProcess.command = [root.binaryPath, "input", "set", "--" + flag + "=" + value, "--json"];
        writeProcess.running = true;
    }

    function apply(text) {
        const data = JSON.parse(text);
        root.current = data.current;
        root.user = data.user;
        root.cursorThemes = data.cursorThemes;
    }

    Process {
        id: readProcess
        stdout: StdioCollector { id: readOutput }
        stderr: StdioCollector { id: readErrors }
        onExited: exitCode => {
            try {
                if (exitCode !== 0) throw new Error(readErrors.text.trim());
                root.apply(readOutput.text);
                root.error = "";
            } catch (e) {
                root.error = "No se pudieron leer los ajustes: " + e.message;
            }
        }
    }

    Process {
        id: writeProcess
        stdout: StdioCollector { id: writeOutput }
        stderr: StdioCollector { id: writeErrors }
        onExited: exitCode => {
            try {
                if (exitCode !== 0) throw new Error(writeErrors.text.trim());
                root.apply(writeOutput.text);
                root.error = "";
            } catch (e) {
                root.error = "No se pudo guardar: " + e.message;
                root.currentChanged();
            }
            root.next();
        }
    }
}
