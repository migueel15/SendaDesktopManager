pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"
    property var values: ({})
    property bool loaded: false
    property bool writing: false
    // A shortcut control is recording; only one may do so at a time.
    property bool recording: false
    property bool refreshQueued: false
    property string notice: ""
    // Flag of the write in progress, reported by saved() on success.
    property string pendingFlag: ""

    // Emitted after a successful write; controls show it without text.
    signal saved(string flag)
    property bool noticeIsError: false
    readonly property bool busy: writing || readProcess.running

    function showError(message) {
        root.noticeIsError = true;
        root.notice = message;
    }

    function refresh() {
        if (root.writing || readProcess.running) {
            root.refreshQueued = true;
            return;
        }
        root.refreshQueued = false;
        readProcess.command = [root.binaryPath, "hyprland", "show", "--json"];
        readProcess.running = true;
    }

    function save(flag, value) {
        if (root.busy || !root.loaded) return false;
        const lock = flag === "--lock-shortcut" ? String(value).trim() : root.values.lockShortcut.trim();
        const dictation = flag === "--dictation-shortcut" ? String(value).trim() : root.values.dictationShortcut.trim();
        if (!lock || !dictation) {
            root.showError("Los atajos no pueden estar vacíos");
            return false;
        }
        if (lock.replace(/\s/g, "").toLowerCase() === dictation.replace(/\s/g, "").toLowerCase()) {
            root.showError("Los atajos de bloqueo y dictado deben ser distintos");
            return false;
        }
        if (flag === "--idle-seconds" && (!/^\d+$/.test(String(value)) || Number(value) > 86400)) {
            root.showError("El tiempo de inactividad debe ser un entero entre 0 y 86400 segundos");
            return false;
        }
        root.writing = true;
        root.notice = "";
        root.noticeIsError = false;
        root.pendingFlag = flag;
        writeProcess.command = [root.binaryPath, "hyprland", "set", flag, String(value).trim(), "--json"];
        writeProcess.running = true;
        return true;
    }

    Process {
        id: readProcess
        stdout: StdioCollector { id: readOutput }
        stderr: StdioCollector { id: readErrors }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.loaded = false;
                root.showError("No se pudieron consultar los ajustes del sistema: " + (readErrors.text.trim() || "error desconocido"));
            } else {
                try {
                    const data = JSON.parse(readOutput.text);
                    if (typeof data.lockShortcut !== "string" || typeof data.dictationShortcut !== "string"
                        || !Number.isInteger(data.idleSeconds) || data.idleSeconds < 0 || data.idleSeconds > 86400
                        || typeof data.blur !== "boolean" || typeof data.modulePath !== "string"
                        || typeof data.moduleActive !== "boolean" || typeof data.idleConfigPath !== "string"
                        || !Array.isArray(data.warnings) || !data.warnings.every(w => typeof w === "string"))
                        throw new Error("invalid response");
                    root.values = data;
                    root.loaded = true;
                } catch (error) {
                    root.loaded = false;
                    root.showError("La respuesta de los ajustes del sistema no es válida");
                }
            }
            if (root.refreshQueued) root.refresh();
        }
    }

    Process {
        id: writeProcess
        stdout: StdioCollector {}
        stderr: StdioCollector { id: writeErrors }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.noticeIsError = false;
                root.notice = "";
                root.saved(root.pendingFlag);
            } else {
                root.showError("No se pudieron guardar los ajustes del sistema: " + (writeErrors.text.trim() || "error desconocido"));
            }
            root.writing = false;
            root.refresh();
        }
    }
}
