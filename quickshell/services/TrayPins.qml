pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/senda"
    readonly property string filePath: stateDirectory + "/tray-pinned.json"
    readonly property bool ready: state.ready
    readonly property var pinnedIds: state.ids

    QtObject {
        id: state

        property bool ready: false
        property bool writable: true
        property var ids: []
        property var pending: []
        property int loadRetries: 0
    }

    function isPinned(id) {
        return pinnedIds.indexOf(id) !== -1;
    }

    function pin(id) {
        change("pin", id);
    }

    function unpin(id) {
        change("unpin", id);
    }

    function change(op, id) {
        if (typeof id !== "string" || id.length === 0)
            return;
        if (!ready) {
            state.pending = state.pending.concat([{op: op, id: id}]);
            return;
        }
        if (applyChange(op, id))
            save();
    }

    function applyChange(op, id) {
        const index = pinnedIds.indexOf(id);
        if ((op === "pin" && index !== -1) || (op === "unpin" && index === -1))
            return false;

        const next = pinnedIds.slice();
        if (op === "pin")
            next.push(id);
        else
            next.splice(index, 1);
        state.ids = next;
        return true;
    }

    function finishLoad(ids) {
        state.ids = ids;
        let changed = false;
        for (const operation of state.pending) {
            if (applyChange(operation.op, operation.id))
                changed = true;
        }
        state.pending = [];
        if (changed)
            save();
        // Publish readiness only after queued operations have been reconciled.
        state.ready = true;
    }

    function load() {
        let ids = [];
        try {
            const data = JSON.parse(stateFile.text());
            if (!data || data.version !== 1 || !Array.isArray(data.pinned))
                throw new Error("unexpected state format");
            for (const id of data.pinned) {
                if (typeof id === "string" && id.length > 0 && ids.indexOf(id) === -1)
                    ids.push(id);
            }
        } catch (error) {
            console.warn("TrayPins: invalid state:", error);
            ids = [];
        }
        finishLoad(ids);
    }

    function loadFailed(error) {
        if (error === FileViewError.FileNotFound) {
            finishLoad([]);
        } else if (state.loadRetries < 3) {
            state.loadRetries++;
            loadRetryTimer.restart();
        } else {
            console.warn("TrayPins: state load failed:", FileViewError.toString(error));
            state.writable = false;
            finishLoad([]);
        }
    }

    function save() {
        if (state.writable)
            stateFile.setText(JSON.stringify({version: 1, pinned: pinnedIds}, null, 2) + "\n");
    }

    Process {
        id: stateDirectoryProcess

        command: ["mkdir", "-p", root.stateDirectory]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                stateFile.path = root.filePath;
            } else {
                console.warn("TrayPins: could not prepare state directory");
                state.writable = false;
                root.finishLoad([]);
            }
        }
    }

    Component.onCompleted: stateDirectoryProcess.running = true

    FileView {
        id: stateFile

        path: ""
        atomicWrites: true
        blockWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: root.load()
        onLoadFailed: error => root.loadFailed(error)
        onSaveFailed: error => console.warn("TrayPins: state save failed:", FileViewError.toString(error))
    }

    Timer {
        id: loadRetryTimer

        interval: 250
        onTriggered: stateFile.reload()
    }
}
