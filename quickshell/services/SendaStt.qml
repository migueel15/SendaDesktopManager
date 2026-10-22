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
    // start opens a dictation only after loaded. Completion returns to standby
    // without releasing the engine; cancel in preparing/standby ends the process.
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
    readonly property string preloadState: root.engineCancelled || root.retiring ? "inactive"
        : root.phase === "preparing" ? "preparing"
        : root.preloadError !== "" ? "error"
        : root.sessionActive && root.standbySession && root.modelLoaded ? "ready" : "inactive"
    property string preloadError: ""
    property int loadFailures: 0
    // This guard is released only by onExited, after the engine is freed.
    property bool sessionActive: false
    property bool standbySession: false
    property bool modelLoaded: false
    property bool dictationRequested: false
    property bool queuedDictation: false
    property bool configurationPending: false
    property bool preloadSuppressed: false
    property bool engineCancelled: false
    property bool retiring: false
    property bool shuttingDown: false

    function refreshPreload() {
        root.loadFailures = 0;
        root.preloadError = "";
        root.configurationPending = root.sessionActive;
        if (root.sessionActive && root.standbySession && !root.dictationRequested
                && (root.phase === "preparing" || root.phase === "standby")) {
            root.retiring = true;
            if (root.sessionStarted) session.signal(15);
        } else if (!root.sessionActive) {
            preloadTimer.restart();
        }
        // An active dictation keeps its settings until the next loaded/exit.
        // Its replacement reads the current config directly through the CLI.
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
        root.engineCancelled = false;
        root.configurationPending = false;
        root.preloadSuppressed = false;
        root.queuedDictation = standby && root.dictationRequested;
        root.pendingCommand = "";
        root.errorMessage = "";
        root.phase = standby ? "preparing" : "starting";
        session.command = [root.binaryPath, "stt", "session"].concat(standby ? ["--standby"] : []);
        session.running = true;
    }

    function beginDictation() {
        // The model is already resident; only the microphone is opening.
        root.queuedDictation = false;
        root.phase = "starting";
        root.sendCommand("start");
    }

    function finishDictation() {
        // Keep the explicit queue until start, so exit recovery never uses
        // the request belonging to the dictation that just ended.
        root.dictationRequested = root.queuedDictation;
        root.phase = "finishing";
        if (!root.dictationRequested) root.scheduleDockClose();
    }

    function toggle() {
        if (!root.standbySession && root.sessionActive && root.phase === "finishing") return "stopping";
        if (root.standbySession && !root.retiring && !root.engineCancelled
                && (root.phase === "stopping" || root.phase === "delivering")) {
            // Stop/cancel during delivery can terminate the resident process.
            root.queuedDictation = !root.queuedDictation;
            if (root.queuedDictation) {
                closeTimer.stop();
                root.dockClosing = false;
            }
            return root.queuedDictation ? "started" : "stopping";
        }
        if (!root.dictationRequested) {
            closeTimer.stop();
            errorTimer.stop();
            preloadTimer.stop();
            root.dictationRequested = true;
            root.queuedDictation = root.standbySession;
            root.transcript = "";
            root.errorMessage = "";
            root.dockClosing = false;
            root.dockVisible = true;
            if (!root.sessionActive) root.launch(root.preloadEnabled);
            else if (!root.retiring && !root.engineCancelled && root.phase === "standby") root.beginDictation();
            // During preparing, loaded will send start. During retirement,
            // onExited will launch the requested dictation.
            return "started";
        }
        if (root.retiring || root.engineCancelled || root.phase === "preparing"
                || root.phase === "standby" || root.phase === "finishing") {
            root.dictationRequested = false;
            root.queuedDictation = false;
            root.scheduleDockClose();
        } else if (root.phase === "starting" || root.phase === "listening") {
            root.phase = "stopping";
            root.sendCommand("stop");
        }
        return "stopping";
    }

    function cancel() {
        if (!root.sessionActive) return false;
        root.queuedDictation = false;
        if (root.engineCancelled || root.retiring) {
            root.dictationRequested = false;
            root.scheduleDockClose();
            return true;
        }
        if (root.standbySession && root.phase === "preparing" && root.dictationRequested) {
            root.dictationRequested = false;
            root.scheduleDockClose();
            return true;
        }
        if (root.standbySession
                && (root.phase === "stopping" || root.phase === "delivering" || root.phase === "finishing")) {
            if (root.phase === "finishing") root.dictationRequested = false;
            root.scheduleDockClose();
            return true;
        }
        if (root.standbySession && !root.dictationRequested
                && (root.phase === "preparing" || root.phase === "standby")) {
            root.preloadSuppressed = true;
            root.engineCancelled = true;
            preloadTimer.stop();
        }
        root.dictationRequested = false;
        root.phase = root.engineCancelled ? "finishing" : "stopping";
        if (root.engineCancelled) root.scheduleDockClose();
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
        // Slightly longer than the dock's close animation, so it is not cut off.
        interval: Theme.motion.slow + 50
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
            if (!root.sessionActive && root.preloadEnabled && !root.preloadSuppressed && root.loadFailures < 3)
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
                    if (root.retiring || root.engineCancelled || root.shuttingDown) return;
                    switch (event.event) {
                    case "loaded":
                        // Empty dictations emit final then loaded, without delivered.
                        if (root.phase === "delivering") root.finishDictation();
                        if (root.configurationPending) {
                            root.retiring = true;
                            session.signal(15);
                            break;
                        }
                        root.modelLoaded = true;
                        root.preloadError = "";
                        root.phase = "standby";
                        if (root.dictationRequested) {
                            closeTimer.stop();
                            root.dockClosing = false;
                            root.transcript = "";
                            root.beginDictation();
                        }
                        break;
                    case "ready":
                        if (root.dictationRequested) root.dockVisible = true;
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
                        if (root.standbySession) root.finishDictation();
                        else {
                            root.dictationRequested = false;
                            root.phase = "finishing";
                        }
                        break;
                    case "error":
                        if (root.dictationRequested) root.dockVisible = true;
                        root.errorMessage = event.message || "Error en la sesión de dictado";
                        root.phase = "error";
                        root.dockClosing = false;
                        errorTimer.restart();
                        break;
                    }
                } catch (error) {
                    if (root.dictationRequested) root.dockVisible = true;
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
            const wasEngineCancelled = root.engineCancelled;
            const pendingDictation = root.standbySession && root.queuedDictation;
            // Loading again is not recovery: idle crashes after loaded count
            // toward the same limit until a dictation reaches ready.
            const loadFailed = root.standbySession && !wasRetiring && !wasEngineCancelled
                && (pendingDictation || (!root.modelLoaded && (exitCode !== 0 || root.phase === "error"))
                    || (!requested && exitCode !== 0));
            root.sessionActive = false;
            root.sessionStarted = false;
            root.pendingCommand = "";
            root.retiring = false;
            if (root.shuttingDown) return;
            if (wasRetiring) {
                root.phase = "idle";
                if (requested) root.launch(root.preloadEnabled);
                else preloadTimer.restart();
                return;
            }
            if (wasEngineCancelled && requested) {
                root.launch(root.preloadEnabled);
                return;
            }
            if (loadFailed) {
                root.loadFailures += 1;
                root.preloadError = root.errorMessage || sessionErrors.text.trim() || "No se pudo precargar el modelo";
                root.errorMessage = root.preloadError;
                root.phase = "error";
            }
            if (pendingDictation && !wasEngineCancelled && root.loadFailures < 3) {
                root.dictationRequested = true;
                root.launch(root.preloadEnabled);
                return;
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
            if (root.preloadEnabled && !root.preloadSuppressed && root.loadFailures < 3) preloadTimer.restart();
        }
    }

    IpcHandler {
        target: "stt"

        function toggle(): string { return root.toggle(); }
        function cancel(): bool { return root.cancel(); }
        function status(): string { return root.status(); }
    }
}
