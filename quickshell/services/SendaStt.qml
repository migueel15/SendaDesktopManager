pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"

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

    function toggle() {
        if (!session.running) {
            root.phase = "starting";
            root.transcript = "";
            root.errorMessage = "";
            root.pendingCommand = "";
            root.dockClosing = false;
            root.dockVisible = true;
            session.command = [root.binaryPath, "stt", "session"];
            session.running = true;
            return "started";
        }
        if (root.phase === "starting" || root.phase === "listening") {
            if (root.phase !== "stopping") {
                root.phase = "stopping";
                root.sendCommand("stop");
            }
        }
        return "stopping";
    }

    function cancel() {
        if (!session.running) return false;
        root.phase = "stopping";
        return root.sendCommand("cancel");
    }

    function status() {
        return session.running ? root.phase : "idle";
    }

    function closeDock() {
        root.phase = "idle";
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

    Process {
        id: session
        stdinEnabled: true
        command: []

        onStarted: {
            root.sessionStarted = true;
            if (root.pendingCommand !== "") {
                session.write(root.pendingCommand + "\n");
                root.pendingCommand = "";
            }
        }

        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    switch (event.event) {
                    case "ready":
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

        onExited: exitCode => {
            root.sessionStarted = false;
            root.pendingCommand = "";
            if (root.phase === "error") {
                errorTimer.restart();
            } else {
                root.phase = "finishing";
                root.scheduleDockClose();
            }
        }
    }

    IpcHandler {
        target: "stt"

        function toggle(): string { return root.toggle(); }
        function cancel(): bool { return root.cancel(); }
        function status(): string { return root.status(); }
    }
}
