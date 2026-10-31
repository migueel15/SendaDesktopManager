pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Monitors through `senda display`. Edits gather in a draft and are applied
// together; the core reverts them unless they are confirmed in time.
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
    property bool confirming: false
    // Pending edits by monitor name, with the same fields as a display.
    property var draft: ({})
    readonly property bool dirty: Object.keys(draft).length > 0
    readonly property bool busy: writeProcess.running || applyProcess.running
    // Monitors as they will be once the draft is applied.
    readonly property var view: displays.map(d => Object.assign({}, d, draft[d.name]))
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

    // Edits wait here until applied; nothing reaches Hyprland before that.
    function stage(name, patch) {
        const next = Object.assign({}, root.draft);
        next[name] = Object.assign({}, next[name], patch);
        root.draft = next;
    }

    function discard() { root.draft = ({}); }

    // The core runs the countdown, so it reverts even if this shell dies.
    function apply() {
        if (!root.dirty || root.confirming || applyProcess.running) return;
        const changes = Object.keys(root.draft).map(name => {
            const d = root.draft[name];
            const change = { name: name };
            if (d.width !== undefined) change.mode = d.width + "x" + d.height + "@" + d.refreshRate;
            if (d.x !== undefined) change.position = d.x + "x" + d.y;
            if (d.scale !== undefined) change.scale = d.scale;
            if (d.transform !== undefined) change.transform = d.transform;
            if (d.mirrorOf !== undefined) change.mirror = d.mirrorOf;
            if (d.enabled !== undefined) change.enabled = d.enabled;
            return change;
        });
        root.notice = "";
        root.noticeIsError = false;
        applyProcess.command = [root.binaryPath, "display", "apply", "--confirm", String(root.confirmSeconds), "--changes", JSON.stringify(changes)];
        applyProcess.running = true;
    }

    function keep() { answerProcess.answer("confirm"); }
    function revert() { answerProcess.answer("cancel"); }

    Timer {
        running: root.confirming && root.confirmLeft > 0
        interval: 1000
        repeat: true
        onTriggered: root.confirmLeft--
    }

    Process {
        id: answerProcess
        function answer(action) {
            answerProcess.command = [root.binaryPath, "display", action];
            answerProcess.running = true;
        }
    }

    Process {
        id: applyProcess
        property string outcome: ""
        stdout: SplitParser {
            onRead: line => {
                if (line === "pending") {
                    root.confirmLeft = root.confirmSeconds;
                    root.confirming = true;
                } else {
                    applyProcess.outcome = line;
                }
            }
        }
        stderr: StdioCollector { id: applyErrors }
        onExited: exitCode => {
            root.confirming = false;
            root.draft = ({});
            if (exitCode !== 0) {
                root.noticeIsError = true;
                root.notice = "No se pudo aplicar: " + (applyErrors.text.trim() || "error desconocido");
            } else if (applyProcess.outcome === "reverted") {
                root.noticeIsError = false;
                root.notice = "Cambios revertidos";
            }
            applyProcess.outcome = "";
            root.refresh();
        }
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
                root.noticeIsError = true;
                root.notice = "No se pudo aplicar: " + (writeErrors.text.trim() || "error desconocido");
            }
            root.refresh();
        }
    }
}
