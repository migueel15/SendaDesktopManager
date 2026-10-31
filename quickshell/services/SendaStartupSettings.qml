pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What runs when Hyprland starts, read and written through `senda startup`.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"
    property var entries: []
    property string notice: ""
    property bool noticeIsError: false
    property var pending: []

    function run(args) {
        root.pending = root.pending.concat([args]);
        root.next();
    }
    function refresh() { root.run(["show"]); }
    function add(kind, name, target) { root.run(["add", "--kind", kind, "--name", name, "--", target]); }
    function remove(target) { root.run(["remove", "--", target]); }
    function setEnabled(target, enabled) { root.run([enabled ? "enable" : "disable", "--", target]); }

    function next() {
        if (process.running || root.pending.length === 0) return;
        const args = root.pending[0];
        root.pending = root.pending.slice(1);
        process.command = [root.binaryPath, "startup", "--json"].concat(args);
        process.running = true;
    }

    Process {
        id: process
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }
        onExited: exitCode => {
            try {
                if (exitCode !== 0) throw new Error(errors.text.trim());
                root.entries = JSON.parse(output.text);
                root.notice = "";
                root.noticeIsError = false;
            } catch (e) {
                root.notice = "No se pudo guardar: " + e.message;
                root.noticeIsError = true;
                root.entriesChanged();
            }
            root.next();
        }
    }
}
