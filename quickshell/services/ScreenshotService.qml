pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string binary: SendaManager.binaryPath
    property bool busy: false
    property bool frozen: false
    property var frames: []
    property int readyFrames: 0
    property string session: ""
    property string editorPath: ""
    property string pendingEditor: ""
    property string message: ""
    property string operation: ""
    property bool working: freezeProcess.running || cropProcess.running || infoProcess.running

    function capture() {
        if (busy || editorPath || working || !Notifications.stateLoaded) return false;
        busy = true;
        message = "";
        const screens = Array.from(Quickshell.screens);
        if (!screens.length) { busy = false; return false; }
        frames = screens.map(screen => ({ screen: screen, path: "" }));
        freezeProcess.command = [binary, "screenshot", "freeze"].concat(screens.map(screen => screen.name));
        freezeProcess.running = true;
        return true;
    }

    function cleanup() {
        frozen = false;
        readyFrames = 0;
        frames = [];
        if (session) Quickshell.execDetached([binary, "screenshot", "cleanup", session]);
        session = "";
        busy = false;
    }

    function fail(error) {
        message = error || "No se pudo completar la captura";
        console.warn("Screenshot:", message);
        if (busy) cleanup();
    }

    function crop(path, x, y, w, h, save, initial) {
        if (cropProcess.running || w < 1 || h < 1) return;
        operation = initial ? "capture" : (save ? "save" : "copy");
        frozen = false;
        cropProcess.command = [binary, "screenshot", "crop", "--in", path,
            "--x", String(x), "--y", String(y), "--w", String(w), "--h", String(h), "--copy"];
        if (!initial) cropProcess.command = cropProcess.command.concat(["--cache=false"]);
        if (save) cropProcess.command = cropProcess.command.concat(["--save"]);
        cropProcess.running = true;
    }

    function openEditor(path) {
        if (busy || working) return false;
        pendingEditor = path;
        infoProcess.command = [binary, "screenshot", "info", path];
        infoProcess.running = true;
        return true;
    }

    function closeEditor() {
        editorPath = "";
        message = "";
    }

    IpcHandler {
        target: "screenshot"
        function capture(): bool { return root.capture(); }
    }

    Process {
        id: freezeProcess
        stdout: StdioCollector { id: freezeOutput }
        stderr: StdioCollector { id: freezeError }
        onExited: code => {
            if (code !== 0) { root.fail(freezeError.text.trim()); return; }
            try {
                const paths = JSON.parse(freezeOutput.text);
                root.session = paths[0].substring(0, paths[0].lastIndexOf("/"));
                if (!root.busy) { root.cleanup(); return; }
                root.readyFrames = 0;
                root.frames = root.frames.map((frame, index) => ({ screen: frame.screen, path: paths[index] }));
                root.frozen = true;
            } catch (error) { root.fail("Respuesta de captura inválida"); }
        }
    }
    Process {
        id: cropProcess
        stdout: StdioCollector { id: cropOutput }
        stderr: StdioCollector { id: cropError }
        onExited: code => {
            if (code !== 0) { root.fail(cropError.text.trim()); return; }
            try {
                const result = JSON.parse(cropOutput.text);
                if (root.operation === "capture") {
                    Notifications.addScreenshot(result.image);
                    root.cleanup();
                } else {
                    root.message = root.operation === "save" ? "Guardada en " + result.path : "Captura copiada al portapapeles";
                }
            } catch (error) { root.fail("Respuesta de recorte inválida"); }
        }
    }
    Process {
        id: infoProcess
        stdout: StdioCollector {}
        onExited: code => {
            // A stale notification simply disappears, without opening a window.
            if (code === 0) {
                root.message = "";
                root.editorPath = root.pendingEditor;
            }
            root.pendingEditor = "";
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() { if (root.busy) root.cleanup(); }
    }
}
