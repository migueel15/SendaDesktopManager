pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"

    // Standby contract: preparing loads without recording; loaded enters standby.
    // start moves standby to starting, then ready enters listening. Cancel during
    // preparing/standby (or stop before start) ends normally; load failures emit error.
    property string phase: "idle"
    property string transcript: ""
    property string errorMessage: ""
    property bool dockVisible: false
    property bool dockClosing: false
    property bool sessionStarted: false
    property string pendingCommand: ""

    function sendCommand(command) {
        if (!session.running) return false;
        if (!root.sessionStarted) {
            root.pendingCommand = command;
            return true;
        }
        session.write(command + "\n");
        return true;
    }

    readonly property bool preloadEnabled: String(SendaSettings.values.SENDA_STT_PRELOAD || "").trim() === "true"
    readonly property string preloadConfiguration: JSON.stringify([
        root.preloadEnabled, SendaSettings.values.SENDA_STT_MODEL || "",
        SendaSettings.values.SENDA_STT_LANGUAGE || ""
    ])
    readonly property string preloadState: root.phase === "preparing" ? "preparing"
        : root.preloadError !== "" ? "error"
        : root.phase === "standby" ? "ready" : "inactive"
    property string preloadError: ""
    property int loadFailures: 0
    // This guard is released only by onExited, after the engine is freed.
    property bool sessionActive: false
    property bool standbySession: false
    property bool modelLoaded: false
    property bool dictationRequested: false
    property bool retiring: false
    property bool shuttingDown: false

    function refreshPreload() {
        root.loadFailures = 0;
        root.preloadError = "";
        if (root.sessionActive && root.standbySession && !root.dictationRequested) {
            root.retiring = true;
            if (root.sessionStarted) session.signal(15);
        } else if (!root.sessionActive) {
            preloadTimer.restart();
        }
        // An active dictation keeps its settings until it exits. The next
        // session reads the current config directly through the CLI.
    }

    onPreloadConfigurationChanged: root.refreshPreload()
    Component.onCompleted: preloadTimer.restart()
    Component.onDestruction: {
        root.shuttingDown = true;
        preloadTimer.stop();
        if (root.sessionActive) session.signal(15);
    }

    function launch(standby) {
        if (root.sessionActive || root.shuttingDown) return;
        root.sessionActive = true;
        root.sessionStarted = false;
        root.standbySession = standby;
        root.modelLoaded = false;
        root.retiring = false;
        root.pendingCommand = "";
        root.errorMessage = "";
        root.phase = standby ? "preparing" : "starting";
        session.command = [root.binaryPath, "stt", "session"].concat(standby ? ["--standby"] : []);
        session.running = true;
    }

    function beginDictation() {
        root.phase = "starting";
        root.sendCommand("start");
    }

    function toggle() {
        if (!root.dictationRequested) {
            closeTimer.stop();
            errorTimer.stop();
            preloadTimer.stop();
            root.dictationRequested = true;
            root.transcript = "";
            root.errorMessage = "";
            root.dockClosing = false;
            root.dockVisible = true;
            if (!root.sessionActive) root.launch(false);
            else if (!root.retiring && root.phase === "standby") root.beginDictation();
            // During preparing, loaded will send start. During retirement,
            // onExited will launch the requested dictation.
            return "started";
        }
        if (root.phase === "preparing") {
            root.dictationRequested = false;
            root.scheduleDockClose();
        } else if (root.phase === "starting" || root.phase === "listening") {
            root.phase = "stopping";
            root.sendCommand("stop");
        }
        return "stopping";
    }

    function cancel() {
        if (!root.sessionActive) return false;
        root.dictationRequested = false;
        root.phase = "stopping";
        return root.sendCommand("cancel");
    }

    function status() {
        return session.running ? root.phase : "idle";
    }

    function closeDock() {
        if (!root.sessionActive) root.phase = "idle";
        root.transcript = "";
        root.errorMessage = "";
        root.dockClosing = false;
        root.dockVisible = false;
    }

    function scheduleDockClose() {
        if (!root.dockVisible || root.dockClosing) return;
        root.dockClosing = true;
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: Theme.motion.slow
        onTriggered: root.closeDock()
    }

    Timer {
        id: errorTimer
        interval: 4000
        onTriggered: root.scheduleDockClose()
    }

    Timer {
        id: preloadTimer
        interval: 1000
        onTriggered: {
            if (!root.sessionActive && root.preloadEnabled && root.loadFailures < 3)
                root.launch(true);
        }
    }

    Process {
        id: session
        stdinEnabled: true
        command: []

        onStarted: {
            root.sessionStarted = true;
            if (root.retiring || root.shuttingDown) {
                session.signal(15);
                return;
            }
            if (root.pendingCommand !== "") {
                session.write(root.pendingCommand + "\n");
                root.pendingCommand = "";
            }
        }

        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (root.retiring || root.shuttingDown) return;
                    switch (event.event) {
                    case "loaded":
                        root.modelLoaded = true;
                        root.preloadError = "";
                        root.phase = "standby";
                        if (root.dictationRequested) root.beginDictation();
                        break;
                    case "ready":
                        root.loadFailures = 0;
                        root.preloadError = "";
                        if (root.phase === "starting") root.phase = "listening";
                        break;
                    case "partial":
                        root.transcript = event.text || "";
                        if (root.phase === "starting") root.phase = "listening";
                        break;
                    case "final":
                        root.transcript = event.text || root.transcript;
                        root.phase = "delivering";
                        break;
                    case "delivered":
                    case "cancelled":
                        root.phase = "finishing";
                        break;
                    case "error":
                        root.errorMessage = event.message || "Error en la sesión de dictado";
                        root.phase = "error";
                        root.dockClosing = false;
                        errorTimer.restart();
                        break;
                    }
                } catch (error) {
                    root.errorMessage = "No se pudo leer la respuesta del dictado";
                    root.phase = "error";
                    root.dockClosing = false;
                    errorTimer.restart();
                }
            }
        }

        stderr: StdioCollector { id: sessionErrors }
        onExited: exitCode => {
            const wasRetiring = root.retiring;
            const requested = root.dictationRequested;
            // Loading again is not recovery: idle crashes after loaded count
            // toward the same limit until a dictation reaches ready.
            const loadFailed = root.standbySession && !wasRetiring
                && ((!root.modelLoaded && (exitCode !== 0 || root.phase === "error"))
                    || (!requested && exitCode !== 0));
            root.sessionActive = false;
            root.sessionStarted = false;
            root.pendingCommand = "";
            root.retiring = false;
            if (root.shuttingDown) return;
            if (wasRetiring) {
                root.phase = "idle";
                if (requested) root.launch(false);
                else preloadTimer.restart();
                return;
            }
            if (loadFailed) {
                root.loadFailures += 1;
                root.preloadError = root.errorMessage || sessionErrors.text.trim() || "No se pudo precargar el modelo";
                root.errorMessage = root.preloadError;
                root.phase = "error";
            }
            root.dictationRequested = false;
            if (root.phase === "error") {
                if (root.dockVisible) errorTimer.restart();
                else root.phase = "idle";
            } else {
                root.phase = "finishing";
                root.scheduleDockClose();
            }
            // cancelled is emitted before engine cleanup; only restart here.
            if (root.preloadEnabled && root.loadFailures < 3) preloadTimer.restart();
        }
    }

    IpcHandler {
        target: "stt"

        function toggle(): string { return root.toggle(); }
        function cancel(): bool { return root.cancel(); }
        function status(): string { return root.status(); }
    }
}
