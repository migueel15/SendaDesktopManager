pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Monitors through `senda display`. Changes that can leave a screen unusable
// are undone unless confirmed in time.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"
    readonly property int confirmSeconds: 15
    property var displays: []
    property bool loaded: false
    property bool canUndo: false
    property string notice: ""
    property bool noticeIsError: false
    property int confirmLeft: 0
    readonly property bool busy: writeProcess.running
    readonly property bool hasUserManaged: displays.some(d => d.managedBy === "user")

    function refresh() {
        if (!readProcess.running) readProcess.running = true;
    }

    function run(args) {
        if (root.busy) return false;
        root.notice = "";
        root.noticeIsError = false;
        writeProcess.command = [root.binaryPath, "display"].concat(args);
        writeProcess.running = true;
        return true;
    }

    function set(name, flag, value) { return root.run(["set", name, flag, String(value)]); }

    // The same as set, but it reverts by itself unless keep() is called.
    function setGuarded(name, flag, value) {
        if (root.set(name, flag, value)) root.confirmLeft = root.confirmSeconds;
    }

    function keep() { root.confirmLeft = 0; }

    function undo() {
        root.confirmLeft = 0;
        root.run(["undo"]);
    }

    Timer {
        running: root.confirmLeft > 0 && !root.busy
        interval: 1000
        repeat: true
        onTriggered: if (--root.confirmLeft === 0) root.undo()
    }

    Process {
        id: readProcess
        command: [root.binaryPath, "display", "show", "--json"]
        stdout: StdioCollector { id: readOutput }
        stderr: StdioCollector { id: readErrors }
        onExited: exitCode => {
            try {
                if (exitCode !== 0) throw new Error(readErrors.text.trim());
                const data = JSON.parse(readOutput.text);
                if (!Array.isArray(data.displays)) throw new Error("respuesta inválida");
                root.displays = data.displays;
                root.canUndo = data.canUndo === true;
                root.loaded = true;
            } catch (error) {
                root.loaded = false;
                root.noticeIsError = true;
                root.notice = "No se pudieron consultar las pantallas: " + (error.message || "error desconocido");
            }
        }
    }

    Process {
        id: writeProcess
        stdout: StdioCollector {}
        stderr: StdioCollector { id: writeErrors }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.confirmLeft = 0;
                root.noticeIsError = true;
                root.notice = "No se pudo aplicar: " + (writeErrors.text.trim() || "error desconocido");
            }
            root.refresh();
        }
    }
}
