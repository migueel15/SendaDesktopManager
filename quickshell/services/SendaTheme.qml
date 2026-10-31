pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.services

Singleton {
    id: root

    property var themes: []
    property var active: null
    property bool busy: listProcess.running || currentProcess.running || mutationProcess.running
    property string lastError: ""
    property bool pickerOpen: false
    property string pickerScreen: ""
    property bool duplicatePending: false
    signal saved(var info)
    signal saveFailed(string error)

    property bool started: false
    property bool closing: false
    property bool reloadPending: false
    property int selectionGeneration: 0
    property int watchGeneration: 0
    property int watchRetries: 0
    property var watcher: null

    function launch(process, args) {
        process.command = [SendaManager.binaryPath, "theme"].concat(args);
        process.running = true;
    }

    function start() {
        if (started)
            return;
        started = true;
        readCurrent(false);
        refresh();
    }

    function refresh() {
        if (listProcess.running) {
            listProcess.pending = true;
            return;
        }
        launch(listProcess, ["list", "--json"]);
    }

    function readCurrent(clearManual) {
        if (currentProcess.running) {
            reloadPending = true;
            return;
        }
        currentProcess.clearManual = clearManual;
        currentProcess.generation = selectionGeneration;
        launch(currentProcess, ["current", "--json", "--notify"]);
    }

    function reload() { readCurrent(true); }

    function mutate(action, name, input) {
        if (mutationProcess.running) {
            lastError = "Hay una operación de temas en curso";
            if (action === "save")
                saveFailed(lastError);
            return;
        }
        lastError = "";
        mutationProcess.action = action;
        mutationProcess.input = input;
        mutationProcess.stdinEnabled = action === "save";
        launch(mutationProcess, action === "save"
            ? ["save", "--json", "--no-reload"]
            : action === "apply" ? ["apply", name, "--json", "--no-reload"]
            : [action, name, "--no-reload"]);
    }

    function apply(name) { mutate("apply", name, ""); }
    function remove(name) { mutate("delete", name, ""); }
    function save(request) { mutate("save", "", JSON.stringify(request)); }

    function openPicker(screenName) {
        pickerScreen = screenName || "";
        pickerOpen = true;
        refresh();
    }

    function openDuplicate(screenName) {
        duplicatePending = true;
        openPicker(screenName);
    }

    function closePicker() {
        duplicatePending = false;
        pickerOpen = false;
    }

    function accept(info, clearManual) {
        if (!info || info.valid !== true || typeof info.name !== "string"
                || !info.colors || typeof info.wallpaper !== "string")
            throw new Error("La respuesta del tema no es válida");
        Theme.applyColors(info.colors);
        Theme.currentTheme = info.name;
        WallpaperService.setThemeWallpaper(info.wallpaper, clearManual);
        active = info;
    }

    // Each process owns its immutable generation and name. Stopped processes
    // can still deliver buffered lines, so invalidate them before sending SIGTERM.
    function stopWatcher() {
        watchGeneration++;
        watchRetry.stop();
        if (watcher) {
            const previous = watcher;
            watcher = null;
            previous.expectedStop = true;
            previous.running = false;
        }
    }

    function startWatcher() {
        if (closing || !active)
            return;
        watcher = watchComponent.createObject(root, {
            generation: watchGeneration, themeName: active.name,
            command: [SendaManager.binaryPath, "theme", "watch", active.name, "--notify"]
        });
        watcher.running = true;
    }

    function restartWatcher() {
        stopWatcher();
        watchRetries = 0;
        startWatcher();
    }

    function watchLine(process, line) {
        if (closing || process !== watcher || process.generation !== watchGeneration
                || !active || process.themeName !== active.name)
            return;
        try {
            const info = JSON.parse(line);
            if (info.name !== active.name || info.valid !== true)
                return;
            accept(info, true);
            watchRetries = 0;
        } catch (error) {
            // Invalid edits are already reported by `theme watch --notify`.
        }
    }

    function watchExited(process) {
        if (!process || process.finished)
            return;
        process.finished = true;
        if (!closing && !process.expectedStop && process === watcher
                && process.generation === watchGeneration && active && process.themeName === active.name) {
            watcher = null;
            if (watchRetries < 5) {
                watchRetries++;
                watchRetry.restart();
            } else {
                lastError = "El vigilante del tema se ha detenido tras cinco reintentos";
            }
        }
        process.destroy();
    }

    Process {
        id: listProcess
        property bool pending: false
        stdout: StdioCollector { id: listOutput }
        stderr: StdioCollector { id: listErrors }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = listErrors.text.trim() || "No se pudieron leer los temas";
            } else {
                try {
                    const data = JSON.parse(listOutput.text);
                    if (!Array.isArray(data))
                        throw new Error("La lista de temas no es válida");
                    root.themes = data;
                } catch (error) { root.lastError = String(error); }
            }
            if (pending) {
                pending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    Process {
        id: currentProcess
        property bool clearManual: false
        property int generation: -1
        stdout: StdioCollector { id: currentOutput }
        stderr: StdioCollector { id: currentErrors }
        onExited: exitCode => {
            // A current read started before apply must not restore the old theme.
            if (generation !== root.selectionGeneration) {
                if (root.reloadPending) {
                    root.reloadPending = false;
                    Qt.callLater(root.reload);
                }
                return;
            }
            if (exitCode !== 0) {
                root.lastError = currentErrors.text.trim() || "No se pudo cargar el tema activo";
            } else {
                try {
                    root.accept(JSON.parse(currentOutput.text), clearManual);
                    root.lastError = "";
                    root.restartWatcher();
                } catch (error) { root.lastError = String(error); }
            }
            if (root.reloadPending) {
                root.reloadPending = false;
                Qt.callLater(root.reload);
            }
        }
    }

    Process {
        id: mutationProcess
        property string action: ""
        property string input: ""
        stdout: StdioCollector { id: mutationOutput }
        stderr: StdioCollector { id: mutationErrors }
        onStarted: {
            if (action === "save") {
                write(input);
                // The CLI checks for a second JSON value until EOF.
                stdinEnabled = false;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = mutationErrors.text.trim() || "No se pudo modificar el tema";
                if (action === "save")
                    root.saveFailed(root.lastError);
                return;
            }
            if (action === "save") {
                try {
                    const info = JSON.parse(mutationOutput.text);
                    if (!info || info.valid !== true || typeof info.name !== "string")
                        throw new Error("La respuesta al guardar no es válida");
                    if (info.active === true)
                        root.reload();
                    root.refresh();
                    root.saved(info);
                } catch (error) {
                    root.lastError = String(error);
                    root.saveFailed(root.lastError);
                }
            } else if (action === "apply") {
                try {
                    root.accept(JSON.parse(mutationOutput.text), true);
                    root.selectionGeneration++;
                    root.reloadPending = false;
                    root.restartWatcher();
                    root.refresh();
                } catch (error) { root.lastError = String(error); }
            } else {
                root.reload();
                root.refresh();
            }
        }
    }

    Component {
        id: watchComponent
        Process {
            id: watchProcess
            property int generation: -1
            property string themeName: ""
            property bool expectedStop: false
            property bool finished: false
            stdout: SplitParser {
                onRead: line => root.watchLine(watchProcess, line)
            }
            onExited: root.watchExited(watchProcess)
            // Also covers failure to start, for which there may be no exit signal.
            onRunningChanged: {
                if (!running)
                    Qt.callLater(root.watchExited, watchProcess);
            }
        }
    }

    Timer {
        id: watchRetry
        interval: 2000
        onTriggered: root.startWatcher()
    }

    Component.onDestruction: {
        closing = true;
        stopWatcher();
    }

    IpcHandler {
        target: "theme"
        function reload() { root.reload(); }
        // Opens on the focused monitor, where the user is looking.
        function openPicker() { root.openPicker(Hyprland.focusedMonitor?.name ?? ""); }
    }
}
