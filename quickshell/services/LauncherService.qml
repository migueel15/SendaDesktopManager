pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// State shared by the launcher panels of every monitor: recent applications,
// launching and the IPC target used by `senda launcher toggle`.
Singleton {
    id: root

    property var recentIds: []
    property var pendingIds: []
    property bool historyReady: false
    property bool historyWritable: true
    readonly property string historyDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/senda"

    function toggle(name) {
        OverlayService.togglePanel("launcher", name || Hyprland.focusedMonitor?.name || "");
    }
    function close() {
        if (OverlayService.isOpen("launcher")) OverlayService.closeCurrentPanel();
    }
    function launch(entry) {
        if (!entry) return;
        root.recordLaunch(entry.id);
        root.close();
        entry.execute();
    }
    function addRecent(id) {
        if (typeof id !== "string" || !id) return;
        root.recentIds = [id].concat(root.recentIds.filter(existing => existing !== id)).slice(0, 100);
    }
    function recordLaunch(id) {
        if (!root.historyReady) {
            root.pendingIds = root.pendingIds.concat([id]);
            root.addRecent(id);
            return;
        }
        root.addRecent(id);
        root.saveHistory();
    }
    function finishHistory(ids) {
        root.recentIds = ids;
        for (const id of root.pendingIds) root.addRecent(id);
        const changed = root.pendingIds.length > 0;
        root.pendingIds = [];
        root.historyReady = true;
        if (changed) root.saveHistory();
    }
    function saveHistory() {
        if (root.historyWritable)
            historyFile.setText(JSON.stringify({version: 1, recent: root.recentIds}, null, 2) + "\n");
    }

    Component.onCompleted: historyDirectoryProcess.running = true
    Process {
        id: historyDirectoryProcess
        command: ["mkdir", "-p", root.historyDirectory]
        onExited: exitCode => {
            if (exitCode === 0) historyFile.path = root.historyDirectory + "/launcher-recent.json";
            else { root.historyWritable = false; root.finishHistory([]); }
        }
    }
    FileView {
        id: historyFile
        path: ""
        atomicWrites: true
        blockWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(historyFile.text());
                if (!data || data.version !== 1 || !Array.isArray(data.recent)) throw new Error("invalid history");
                const ids = [];
                for (const id of data.recent)
                    if (typeof id === "string" && id && !ids.includes(id) && ids.length < 100) ids.push(id);
                root.finishHistory(ids);
            } catch (error) {
                console.warn("Launcher: invalid history:", error);
                root.historyWritable = false;
                root.finishHistory([]);
            }
        }
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn("Launcher: history load failed:", FileViewError.toString(error));
                root.historyWritable = false;
            }
            root.finishHistory([]);
        }
        onSaveFailed: error => console.warn("Launcher: history save failed:", FileViewError.toString(error))
    }
    IpcHandler {
        target: "launcher"
        function toggle() { root.toggle(""); }
        function toggleOnScreen(screenName: string) { root.toggle(screenName); }
    }
}
