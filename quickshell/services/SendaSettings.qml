pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.common
import qs.services

// Backs the settings panel. Every read and write goes through the `senda`
// CLI, which owns the config file and the Google token. Secrets are sent on
// stdin, so they never appear in a command line.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"

    property var values: ({})
    property bool configLoaded: false
    readonly property bool discordWidgetEnabled: configLoaded && values.SENDA_WIDGET_DISCORD !== "false"
    // Resolve the dictation singleton after this singleton has finished loading:
    // dictation itself reads SendaSettings during initialization.
    property var sttService: null
    readonly property bool discordStopSafe: sttService !== null && (!sttService.sessionActive
        || (sttService.standbySession && !sttService.dictationRequested
            && (sttService.phase === "standby" || sttService.phase === "preparing")))
    property int discordApplied: -1
    property bool discordActionEnabled: false
    onDiscordWidgetEnabledChanged: reconcileDiscord()
    onDiscordStopSafeChanged: reconcileDiscord()
    onConfigLoadedChanged: reconcileDiscord()

    function reconcileDiscord() {
        if (!configLoaded || discordProcess.running) return;
        const wanted = discordWidgetEnabled ? 1 : 0;
        if (discordApplied === wanted || (!wanted && !discordStopSafe)) return;
        discordActionEnabled = !!wanted;
        discordProcess.command = [binaryPath, "discord", wanted ? "connect" : "stop"];
        discordProcess.running = true;
    }

    Process {
        id: discordProcess
        stderr: StdioCollector { id: discordErrors }
        onExited: exitCode => {
            root.discordApplied = root.discordActionEnabled ? 1 : 0;
            // connect may fail when Discord is closed even though the bridge started.
            if (exitCode !== 0 && !root.discordActionEnabled)
                root.showError(discordErrors.text, "No se pudo detener el puente de Discord");
            root.reconcileDiscord();
        }
    }
    property bool secretConfigured: false
    // True when this build ships Senda's own Google OAuth client.
    property bool embeddedClient: false
    // Capital used for the weather when no place is chosen, from the system time zone.
    property string defaultWeatherLocation: ""
    property bool connected: false
    property var calendars: []
    property var places: []
    // Last result shown to the user, such as "Guardado" or an error.
    property string notice: ""
    property bool noticeIsError: false
    // Shown when the pending save finishes without an error.
    property string pendingSuccess: ""
    // JSON sent on stdin by the save process, once it has started.
    property string pendingInput: ""

    readonly property bool busy: configProcess.running || statusProcess.running || calendarsProcess.running
        || saveProcess.running || loginProcess.running || logoutProcess.running || searchProcess.running

    function start(process, command) {
        process.command = command;
        process.running = true;
    }

    function refresh() {
        if (!configProcess.running) {
            root.start(configProcess, [root.binaryPath, "config", "get"]);
        }
        if (!statusProcess.running) {
            root.start(statusProcess, [root.binaryPath, "calendar", "status"]);
        }
    }

    // Focus-loss commits can overlap a click on another setting. Serialize
    // those writes instead of dropping the second change.
    QtObject {
        id: saveQueue
        property var pending: []
    }

    function save(changes, successMessage) {
        if (saveProcess.running) {
            saveQueue.pending = saveQueue.pending.concat([{ changes: changes, message: successMessage }]);
            return;
        }
        root.notice = "";
        root.noticeIsError = false;
        root.pendingSuccess = successMessage;
        // The JSON is written once the process has started, because writing
        // before that loses the data and `config set` then receives nothing.
        root.pendingInput = JSON.stringify(changes);
        root.start(saveProcess, [root.binaryPath, "config", "set"]);
    }

    // Saves the OAuth client. The secret is optional when one is already stored.
    function saveGoogleClient(clientId, clientSecret) {
        const changes = { SENDA_GOOGLE_CLIENT_ID: clientId.trim() };
        if (clientSecret.trim() !== "") {
            changes.SENDA_GOOGLE_CLIENT_SECRET = clientSecret.trim();
        }
        root.save(changes, "Credenciales de Google guardadas");
    }

    // An empty list clears the choice, so Senda shows the calendars Google
    // marks as selected.
    function saveCalendars(ids) {
        root.save({ SENDA_GOOGLE_CALENDARS: ids.join(",") }, "Calendarios guardados");
    }

    function saveLocation(place) {
        const label = [place.name, place.admin, place.country].filter(part => part).join(", ");
        root.save({
            SENDA_WEATHER_LOCATION: label,
            SENDA_WEATHER_LAT: String(place.latitude),
            SENDA_WEATHER_LON: String(place.longitude)
        }, "Ubicación guardada");
    }

    function connectGoogle() {
        if (loginProcess.running) {
            return;
        }
        root.notice = "Completa el inicio de sesión en el navegador";
        root.noticeIsError = false;
        root.start(loginProcess, [root.binaryPath, "calendar", "login"]);
    }

    function disconnectGoogle() {
        if (logoutProcess.running) {
            return;
        }
        root.start(logoutProcess, [root.binaryPath, "calendar", "logout"]);
    }

    function searchPlaces(query) {
        if (searchProcess.running || query.trim().length < 2) {
            return;
        }
        root.start(searchProcess, [root.binaryPath, "weather", "search", query.trim()]);
    }

    function showError(text, fallback) {
        root.notice = text.trim() || fallback;
        root.noticeIsError = true;
    }

    Process {
        id: configProcess
        stdout: StdioCollector {
            id: configOutput
        }
        stderr: StdioCollector {
            id: configErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.configLoaded = true;
                root.showError(configErrors.text, "No se pudo leer la configuración");
                return;
            }
            try {
                const data = JSON.parse(configOutput.text);
                root.values = data.values;
                root.configLoaded = true;
                root.secretConfigured = data.googleClientSecretConfigured;
                root.embeddedClient = data.embeddedGoogleClient;
                root.defaultWeatherLocation = data.defaultWeatherLocation ?? "";
                Theme.setFontScale(data.values.SENDA_UI_FONT_SCALE);
            } catch (error) {
                root.configLoaded = true;
                root.showError("La configuración no es válida", "");
            }
        }
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            id: statusOutput
        }
        onExited: exitCode => {
            root.connected = exitCode === 0 && statusOutput.text.trim() === "connected";
            if (root.connected) {
                root.start(calendarsProcess, [root.binaryPath, "calendar", "list"]);
            } else {
                root.calendars = [];
            }
        }
    }

    Process {
        id: calendarsProcess
        stdout: StdioCollector {
            id: calendarsOutput
        }
        stderr: StdioCollector {
            id: calendarsErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.showError(calendarsErrors.text, "No se pudieron leer los calendarios");
                return;
            }
            try {
                root.calendars = JSON.parse(calendarsOutput.text).calendars;
            } catch (error) {
                root.showError("La lista de calendarios no es válida", "");
            }
        }
    }

    Process {
        id: saveProcess
        stdinEnabled: true
        onStarted: saveProcess.write(root.pendingInput)
        stderr: StdioCollector {
            id: saveErrors
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.notice = root.pendingSuccess;
                root.noticeIsError = false;
                // The weather reads the saved location, so it can only be
                // requested once the save has finished.
                SendaWeather.refresh();
            } else {
                root.showError(saveErrors.text, "No se pudo guardar la configuración");
            }
            if (saveQueue.pending.length > 0) {
                const next = saveQueue.pending[0];
                saveQueue.pending = saveQueue.pending.slice(1);
                root.save(next.changes, next.message);
            } else {
                root.refresh();
            }
        }
    }

    Process {
        id: loginProcess
        stdout: StdioCollector {
            id: loginOutput
        }
        stderr: StdioCollector {
            id: loginErrors
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.notice = "Cuenta de Google conectada";
                root.noticeIsError = false;
                root.refresh();
                SendaCalendar.invalidate();
            } else {
                root.showError(loginErrors.text, "No se pudo conectar con Google");
            }
        }
    }

    Process {
        id: logoutProcess
        stderr: StdioCollector {
            id: logoutErrors
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.notice = "Cuenta de Google desconectada";
                root.noticeIsError = false;
            } else {
                root.showError(logoutErrors.text, "No se pudo desconectar la cuenta");
            }
            root.refresh();
            SendaCalendar.invalidate();
        }
    }

    Process {
        id: searchProcess
        stdout: StdioCollector {
            id: searchOutput
        }
        stderr: StdioCollector {
            id: searchErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.places = [];
                root.showError(searchErrors.text, "No se pudo buscar la localidad");
                return;
            }
            try {
                root.places = JSON.parse(searchOutput.text).places;
            } catch (error) {
                root.places = [];
                root.showError("La búsqueda no es válida", "");
            }
        }
    }

    // Reads the settings once at startup, so the interface scale applies before
    // the panel is opened.
    Component.onCompleted: {
        root.refresh();
        Qt.callLater(() => { root.sttService = SendaStt; });
    }

    // `senda settings` calls this through the running shell.
    IpcHandler {
        target: "settings"

        function open() {
            OverlayService.setCurrentPanel("settings");
            root.refresh();
        }
    }
}
