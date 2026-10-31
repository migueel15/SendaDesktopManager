pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/senda"
    readonly property string filePath: stateDirectory + "/wallpapers.json"

    readonly property string wallpapersDirectory: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/senda/wallpapers"
    property bool pickerOpen: false
    property string pickerScreen: ""

    signal changed(string screenName)

    function openPicker(screenName) {
        pickerScreen = screenName || "";
        pickerOpen = true;
    }

    function closePicker() { pickerOpen = false; }

    // Until the theme is reloaded; the manual selection stays across restarts.
    function setForSession(path) {
        return set({path: path, monitor: "", resize: "crop", transition: transition("fade", 800)});
    }

    QtObject {
        id: state

        property bool ready: false
        property bool writable: true
        property int loadRetries: 0
        property double serial: 0
        property string themePath: ""
        property var manuals: Object.create(null)
        property var effective: Object.create(null)
        property var pending: []
    }

    function transition(type, durationMs) {
        return {type: type, durationMs: durationMs, pos: null, bezier: [0.25, 0.1, 0.25, 1]};
    }

    function current(screenName) {
        return state.effective[screenName] || {
            path: state.manuals[screenName] ? state.manuals[screenName].path : state.themePath,
            resize: state.manuals[screenName] ? state.manuals[screenName].resize : "crop",
            transition: transition("none", 0), serial: 0
        };
    }

    function publish(screenName, animation) {
        const manual = state.manuals[screenName];
        state.serial++;
        state.effective[screenName] = {
            path: manual ? manual.path : state.themePath,
            resize: manual ? manual.resize : "crop",
            transition: animation, serial: state.serial
        };
        root.changed(screenName);
    }

    function validate(request) {
        if (!request || typeof request !== "object" || Array.isArray(request))
            return "wallpaper request must be an object";
        if (typeof request.path !== "string" || request.path.trim().length === 0)
            return "wallpaper path must not be empty";
        if (typeof request.monitor !== "string")
            return "wallpaper monitor must be a string";
        if (["none", "crop", "fit", "stretch"].indexOf(request.resize) === -1)
            return "unknown wallpaper resize mode";
        const animation = request.transition;
        if (!animation || ["none", "fade", "wipe", "wave", "grow", "center", "any", "outer", "random"].indexOf(animation.type) === -1)
            return "unknown wallpaper transition type";
        if (typeof animation.durationMs !== "number" || !Number.isFinite(animation.durationMs) || animation.durationMs < 0)
            return "invalid wallpaper transition duration";
        if (animation.pos !== null && (!animation.pos || typeof animation.pos.x !== "number" || !Number.isFinite(animation.pos.x)
                || typeof animation.pos.y !== "number" || !Number.isFinite(animation.pos.y)))
            return "invalid wallpaper transition position";
        if (!Array.isArray(animation.bezier) || animation.bezier.length !== 4)
            return "invalid wallpaper transition bezier";
        for (const value of animation.bezier) {
            if (typeof value !== "number" || !Number.isFinite(value))
                return "invalid wallpaper transition bezier";
        }
        return "";
    }

    function set(request) {
        const error = validate(request);
        if (error !== "")
            return error;
        const names = [];
        for (const screen of Quickshell.screens) {
            if (request.monitor === "" || request.monitor === screen.name)
                names.push(screen.name);
        }
        if (names.length === 0)
            return "no matching wallpaper screen";
        // Capture the request and screen names now, including during startup.
        const operation = {names: names, request: JSON.parse(JSON.stringify(request))};
        if (!state.ready)
            state.pending = state.pending.concat([operation]);
        else
            applyManual(operation);
        return "";
    }

    function applyManual(operation) {
        for (const name of operation.names) {
            state.manuals[name] = {path: operation.request.path, resize: operation.request.resize};
            publish(name, operation.request.transition);
        }
        save();
    }

    function setThemeWallpaper(path, clearManual) {
        const operation = {path: path, clearManual: clearManual};
        if (!state.ready)
            state.pending = state.pending.concat([operation]);
        else
            applyTheme(operation);
    }

    function applyTheme(operation) {
        state.themePath = operation.path;
        if (operation.clearManual) {
            state.manuals = Object.create(null);
            // Also discard cached entries for disconnected screens.
            state.effective = Object.create(null);
            save();
        }
        for (const screen of Quickshell.screens) {
            if (operation.clearManual || !state.manuals[screen.name])
                publish(screen.name, transition(operation.clearManual ? "fade" : "none", operation.clearManual ? 800 : 0));
        }
    }

    function finishLoad(manuals) {
        state.manuals = manuals;
        for (const name of Object.keys(manuals))
            publish(name, transition("none", 0));
        state.ready = true;
        for (const operation of state.pending) {
            if (operation.names)
                applyManual(operation);
            else
                applyTheme(operation);
        }
        state.pending = [];
    }

    function load() {
        const manuals = Object.create(null);
        try {
            const data = JSON.parse(stateFile.text());
            if (!data || typeof data !== "object" || Array.isArray(data))
                throw new Error("unexpected state format");
            for (const name of Object.keys(data)) {
                const entry = data[name];
                if (name.length > 0 && entry && typeof entry.path === "string" && entry.path.trim().length > 0
                        && ["none", "crop", "fit", "stretch"].indexOf(entry.resize) !== -1)
                    manuals[name] = {path: entry.path, resize: entry.resize};
            }
        } catch (error) {
            console.warn("WallpaperService: invalid state:", error);
        }
        finishLoad(manuals);
    }

    function loadFailed(error) {
        if (error === FileViewError.FileNotFound) {
            finishLoad(Object.create(null));
        } else if (state.loadRetries < 3) {
            state.loadRetries++;
            loadRetryTimer.restart();
        } else {
            console.warn("WallpaperService: state load failed:", FileViewError.toString(error));
            state.writable = false;
            finishLoad(Object.create(null));
        }
    }

    function save() {
        if (state.writable)
            stateFile.setText(JSON.stringify(state.manuals, null, 2) + "\n");
    }

    Process {
        id: stateDirectoryProcess

        command: ["mkdir", "-p", root.stateDirectory]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                stateFile.path = root.filePath;
            } else {
                console.warn("WallpaperService: could not prepare state directory");
                state.writable = false;
                root.finishLoad(Object.create(null));
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
        onSaveFailed: error => console.warn("WallpaperService: state save failed:", FileViewError.toString(error))
    }

    Timer {
        id: loadRetryTimer

        interval: 250
        onTriggered: stateFile.reload()
    }

    IpcHandler {
        target: "wallpaper"

        // Opens on the focused monitor, where the user is looking.
        function openPicker(): void { root.openPicker(Hyprland.focusedMonitor?.name ?? ""); }

        function set(request: string): string {
            try {
                return root.set(JSON.parse(request));
            } catch (error) {
                return "invalid wallpaper request: " + error;
            }
        }
    }
}
