pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"
    readonly property bool keyboardEnabled: keyboardState.enabled

    function toggleKeyboard() {
        if (!keyboardToggleProcess.running)
            keyboardToggleProcess.running = true;
    }

    QtObject {
        id: keyboardState
        property bool enabled: true
    }

    Process {
        id: keyboardToggleProcess
        command: [root.binaryPath, "keyboard", "toggle"]
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                keyboardStatus.running = true;
        }
    }

    Component.onCompleted: {
        keyboardStatus.running = true;
        keyboardWatch.running = true;
        displayWatch.running = true;
    }
    Process { id: keyboardWatch; command: [root.binaryPath, "keyboard", "watch"]; onExited: watchRetry.restart() }
    // Keeps generated monitor rules from beating what the user defines.
    Process { id: displayWatch; command: [root.binaryPath, "display", "watch"]; onExited: displayWatchRetry.restart() }
    Timer { id: displayWatchRetry; interval: 5000; onTriggered: displayWatch.running = true }
    Timer { id: watchRetry; interval: 1000; onTriggered: keyboardWatch.running = true }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: if (!keyboardStatus.running) keyboardStatus.running = true }
    Process {
        id: keyboardStatus
        command: [root.binaryPath, "keyboard", "status"]
        stdout: StdioCollector { onStreamFinished: { try { keyboardState.enabled = JSON.parse(text).status === "on"; } catch (e) { console.warn("Estado del teclado:", e); } } }
    }

    function setWallpaper(screen, path, x, y) {
        const position = `${x},${y}`;
        let localPath = String(path);
        if (localPath.startsWith("file://")) {
            localPath = localPath.slice(7);
            if (localPath.startsWith("localhost/"))
                localPath = localPath.slice(9);
            if (!localPath.startsWith("/"))
                return;
            try {
                localPath = decodeURIComponent(localPath);
            } catch (error) {
                console.warn("Senda: invalid wallpaper file URL:", error);
                return;
            }
        }
        run([binaryPath, "wallpaper", "set", "--monitor", screen.name, "--transition-type", "grow", "--pos", position, localPath]);
    }

    function run(command) {
        console.log("Senda command:", command.join(" "));

        process.command = command;
        process.running = true;
    }

    Process {
        id: process
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("zdm stdout:", this.text);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                console.warn("zdm stderr:", this.text);
            }
        }

        onExited: exitCode => {
            console.log("zdm exited with code:", exitCode);
        }

        onStarted: {
            console.log("zdm started:", command);
        }
    }
}
