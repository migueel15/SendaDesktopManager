pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var binaryPath: "/home/miguel/repos/SendaDesktopManager/core/dist/senda"

    function setWallpaper(screen, path, x, y) {
        const position = `${x},${y}`;
        run([binaryPath, "wallpaper", "set", "--transition-fps", 200, "--transition-type", "grow", "--pos", position, path]);
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
