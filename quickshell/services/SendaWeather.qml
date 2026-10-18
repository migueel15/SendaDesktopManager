pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reads the weather for the location chosen in the settings panel, through
// `senda weather current`.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"

    // "loading", "ready", "unconfigured" or "error".
    property string status: "loading"
    property string message: ""
    property string location: ""
    // { temperature, min, max, condition, label } when status is "ready".
    property var current: null

    function refresh() {
        if (weatherProcess.running) {
            return;
        }
        weatherProcess.command = [root.binaryPath, "weather", "current"];
        weatherProcess.running = true;
    }

    Process {
        id: weatherProcess
        running: false

        stdout: StdioCollector {
            id: weatherOutput
        }

        stderr: StdioCollector {
            id: weatherErrors
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(weatherOutput.text);
                    root.current = data.current;
                    root.location = data.location ?? "";
                    root.status = "ready";
                    root.message = "";
                } catch (error) {
                    root.status = "error";
                    root.message = "La respuesta del clima no es válida";
                }
            } else if (weatherErrors.text.includes("no weather location is set")) {
                root.current = null;
                root.status = "unconfigured";
                root.message = "";
            } else {
                root.status = "error";
                root.message = weatherErrors.text.trim() || "No se pudo leer el clima";
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
