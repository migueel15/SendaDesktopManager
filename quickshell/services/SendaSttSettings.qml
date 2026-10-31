pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The CLI owns the STT configuration and model files.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"

    property var runtime: ({ installed: false, provider: "" })
    property var models: []
    property var postprocess: ({ ready: false, supported: true, message: "Consultando disponibilidad", sizeBytes: 1130102020 })
    property string postprocessPhase: ""
    property string postprocessError: ""
    property string installingId: ""
    property real progress: 0
    property string notice: ""
    property bool noticeIsError: false

    // Set before starting the process, so another click cannot start a second write.
    property string operation: ""
    property bool cancelRequested: false
    property bool runtimeRefreshQueued: false
    property bool modelsRefreshQueued: false
    property bool postprocessRefreshQueued: false

    readonly property bool busy: root.operation !== "" || runtimeProcess.running
        || modelsProcess.running || postprocessProcess.running

    readonly property bool preloadEnabled: SendaStt.preloadEnabled
    readonly property bool postprocessEnabled: String(SendaSettings.values.SENDA_STT_POSTPROCESS || "false") === "true"

    function setPostprocess(enabled) {
        if (enabled && !root.postprocess.ready) {
            root.preparePostprocess();
            return;
        }
        SendaSettings.save({ SENDA_STT_POSTPROCESS: enabled ? "true" : "false" }, "Corrección local guardada");
    }

    function preparePostprocess() {
        if (!root.postprocess.supported || !root.startWrite("postprocess", [root.binaryPath, "stt", "postprocess", "install"], "Corrección local preparada")) return;
        root.progress = 0;
        root.postprocessError = "";
        root.postprocessPhase = "Preparando corrección";
    }
    readonly property string preloadState: SendaStt.preloadState
    readonly property string preloadError: SendaStt.preloadError

    readonly property bool audioDuckingEnabled: String(SendaSettings.values.SENDA_STT_AUDIO_DUCKING || "true") !== "false"
    readonly property int audioVolume: Number(SendaSettings.values.SENDA_STT_AUDIO_VOLUME || "10")

    function setAudioDucking(enabled) {
        SendaSettings.save({ SENDA_STT_AUDIO_DUCKING: enabled ? "true" : "false" }, "Atenuación de volumen guardada");
    }

    function setAudioVolume(percent) {
        SendaSettings.save({ SENDA_STT_AUDIO_VOLUME: String(percent) }, "Volumen del dictado guardado");
    }

    function setPreload(enabled) {
        SendaSettings.save({ SENDA_STT_PRELOAD: enabled ? "true" : "false" }, "Preferencia de precarga guardada");
    }

    function showError(message, fallback) {
        root.notice = message.trim() || fallback;
        root.noticeIsError = true;
    }

    function startRead(process, command, queuedProperty) {
        if (root.operation !== "" || process.running) {
            root[queuedProperty] = true;
            return;
        }
        root[queuedProperty] = false;
        process.command = command;
        process.running = true;
    }

    function refresh() {
        root.startRead(runtimeProcess, [root.binaryPath, "stt", "runtime", "status", "--json"], "runtimeRefreshQueued");
        root.startRead(modelsProcess, [root.binaryPath, "stt", "models", "list", "--json"], "modelsRefreshQueued");
        root.startRead(postprocessProcess, [root.binaryPath, "stt", "postprocess", "status", "--json"], "postprocessRefreshQueued");
    }

    function finishRead(process, queuedProperty, command) {
        if (root[queuedProperty] && root.operation === "") {
            root[queuedProperty] = false;
            process.command = command;
            process.running = true;
        }
    }

    function startWrite(name, command, successMessage) {
        if (root.operation !== "") {
            root.showError("Hay otra operación de dictado en curso", "");
            return false;
        }
        root.operation = name;
        root.cancelRequested = false;
        root.notice = "";
        root.noticeIsError = false;
        root.successMessage = successMessage;
        writeProcess.command = command;
        writeProcess.running = true;
        return true;
    }

    property string successMessage: ""

    function installRuntime() {
        root.startWrite("runtime", [root.binaryPath, "stt", "runtime", "install"], "Motor de dictado instalado");
    }

    function installModel(id) {
        if (!id || !root.startWrite("installModel", [root.binaryPath, "stt", "models", "install", id], "Modelo instalado")) {
            return;
        }
        root.installingId = id;
        root.progress = 0;
    }

    function cancelInstall() {
        if ((root.operation !== "installModel" && root.operation !== "postprocess") || root.cancelRequested) {
            return;
        }
        root.cancelRequested = true;
        if (writeProcess.running) writeProcess.signal(15);
    }

    function removeModel(id) {
        if (id) {
            root.startWrite("removeModel", [root.binaryPath, "stt", "models", "remove", id], "Modelo eliminado");
        }
    }

    function useModel(id) {
        if (id) {
            root.startWrite("useModel", [root.binaryPath, "stt", "models", "use", id], "Modelo seleccionado");
        }
    }

    Process {
        id: runtimeProcess
        stdout: StdioCollector { id: runtimeOutput }
        stderr: StdioCollector { id: runtimeErrors }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.showError(runtimeErrors.text, "No se pudo consultar el motor de dictado");
            } else {
                try {
                    const data = JSON.parse(runtimeOutput.text);
                    if (typeof data.installed !== "boolean" || typeof data.provider !== "string") throw new Error("invalid runtime");
                    root.runtime = data;
                } catch (error) {
                    root.showError("El estado del motor no es válido", "");
                }
            }
            root.finishRead(runtimeProcess, "runtimeRefreshQueued", [root.binaryPath, "stt", "runtime", "status", "--json"]);
        }
    }

    Process {
        id: modelsProcess
        stdout: StdioCollector { id: modelsOutput }
        stderr: StdioCollector { id: modelsErrors }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.showError(modelsErrors.text, "No se pudieron consultar los modelos");
            } else {
                try {
                    const data = JSON.parse(modelsOutput.text);
                    if (!Array.isArray(data)) throw new Error("invalid models");
                    root.models = data;
                } catch (error) {
                    root.showError("La lista de modelos no es válida", "");
                }
            }
            root.finishRead(modelsProcess, "modelsRefreshQueued", [root.binaryPath, "stt", "models", "list", "--json"]);
        }
    }

    Process {
        id: postprocessProcess
        stdout: StdioCollector { id: postprocessOutput }
        stderr: StdioCollector { id: postprocessErrors }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.postprocess = { ready: false, supported: true, message: "No se pudo consultar la corrección", sizeBytes: 1130102020 };
                root.showError(postprocessErrors.text, "No se pudo consultar la corrección");
            } else {
                try {
                    const data = JSON.parse(postprocessOutput.text);
                    if (typeof data.ready !== "boolean" || typeof data.supported !== "boolean" || typeof data.message !== "string") throw new Error("invalid postprocess status");
                    root.postprocess = data;
                } catch (error) {
                    root.postprocess = { ready: false, supported: true, message: "Estado de corrección no válido", sizeBytes: 1130102020 };
                    root.showError("El estado de la corrección no es válido", "");
                }
            }
            root.finishRead(postprocessProcess, "postprocessRefreshQueued", [root.binaryPath, "stt", "postprocess", "status", "--json"]);
        }
    }

    Process {
        id: writeProcess
        onStarted: {
            if (root.cancelRequested) writeProcess.signal(15);
        }
        stdout: SplitParser {
            onRead: line => {
                if ((root.operation !== "installModel" && root.operation !== "postprocess") || root.cancelRequested) return;
                try {
                    const event = JSON.parse(line);
                    if (event.event === "progress" && event.total > 0) {
                        root.progress = Math.max(0, Math.min(1, event.done / event.total));
                        if (root.operation === "postprocess") root.postprocessPhase = event.phase || "Preparando corrección";
                    }
                } catch (error) {
                    // Other commands print text; their exit code determines success.
                }
            }
        }
        stderr: StdioCollector { id: writeErrors }
        onExited: exitCode => {
            const wasCancelled = root.cancelRequested;
            if (exitCode === 0) {
                root.notice = root.successMessage;
                root.noticeIsError = false;
                if (root.operation === "postprocess") {
                    SendaSettings.save({ SENDA_STT_POSTPROCESS: "true", SENDA_STT_POSTPROCESS_MODEL: "" }, "Corrección local activada");
                }
            } else if (wasCancelled) {
                root.notice = "Instalación cancelada";
                root.noticeIsError = false;
            } else {
                root.showError(writeErrors.text, "No se pudo completar la operación de dictado");
            }
            if (root.operation === "postprocess" && exitCode !== 0) {
                root.postprocessError = wasCancelled ? "Preparación cancelada. Activa la opción para reintentar" : "No se pudo preparar la corrección. Activa la opción para reintentar";
            }
            if (exitCode === 0 && (root.operation === "useModel" || root.operation === "removeModel"
                || root.operation === "runtime" || root.operation === "postprocess")) {
                SendaStt.refreshPreload();
                SendaSettings.refresh();
            }
            root.operation = "";
            root.installingId = "";
            root.progress = 0;
            root.postprocessPhase = "";
            root.cancelRequested = false;
            root.refresh();
        }
    }
}
