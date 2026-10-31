pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Looks for a newer Senda release through `senda update --check`, and starts
// the update when the user asks for it.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"

    property string current: ""
    property string latest: ""
    property bool available: false
    // feat, fix and perf commits between the installed and the latest release.
    property var changes: []
    property string message: ""
    // Release whose notice the user closed. A new release shows the notice again.
    property string dismissedTag: ""

    // True from the moment the update starts until the new shell replaces this one.
    property bool installing: false

    readonly property bool busy: checkProcess.running
    readonly property bool noticeVisible: root.available && root.latest !== "" && root.latest !== root.dismissedTag

    // Asks the settings window to show the update section.
    signal openRequested()

    function check() {
        if (!checkProcess.running) {
            checkProcess.running = true;
        }
    }

    function openSettings() {
        root.openRequested();
        SendaSettings.openSection("Actualización");
    }

    function dismiss() {
        root.dismissedTag = root.latest;
    }

    // The update stops the shell that started it, so it runs detached to finish
    // and start the new shell.
    function install() {
        if (root.installing) {
            return;
        }
        root.installing = true;
        root.message = "";
        Quickshell.execDetached([root.binaryPath, "update"]);
        installTimeout.restart();
    }

    // The new shell normally replaces this one well before this fires; if it
    // does not, the update failed and the button becomes usable again.
    Timer {
        id: installTimeout
        interval: 5 * 60 * 1000
        onTriggered: {
            root.installing = false;
            root.message = "La actualización no terminó; vuelve a intentarlo";
            root.check();
        }
    }

    Process {
        id: checkProcess
        command: [root.binaryPath, "update", "--check"]

        stdout: StdioCollector {
            id: checkOutput
        }

        stderr: StdioCollector {
            id: checkErrors
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.message = checkErrors.text.trim() || "No se pudo comprobar la versión";
                return;
            }
            try {
                const data = JSON.parse(checkOutput.text);
                root.current = data.current;
                root.latest = data.latest;
                root.available = data.available;
                root.changes = Array.isArray(data.changes) ? data.changes : [];
                root.message = "";
            } catch (error) {
                root.message = "La respuesta de la comprobación no es válida";
            }
        }
    }

    Timer {
        // latest.json comes from the release downloads, not the rate-limited
        // GitHub API, so frequent checks are cheap.
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.check()
    }

    Component.onCompleted: root.check()
}
