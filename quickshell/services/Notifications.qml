pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property string stateFilePath: Quickshell.stateDir + "/notifications.json"
    readonly property int popupLifetimeMs: 5000
    readonly property int popupFadeDurationMs: 180
    property var unreadNotifications: []
    property alias activePopups: popupModel
    property bool hasNotifications: unreadNotifications.length > 0
    readonly property var recentNotifications: unreadNotifications.slice().reverse()
    property bool dndEnabled: false
    property bool stateLoaded: false
    property bool stateDirectoryReady: false
    property bool saveInProgress: false
    property int nextId: 1
    property int revision: 0
    property int savingRevision: 0
    property var liveNotifications: ({
    })
    property var recentServerIds: ({
    })
    property var pausedPopups: ({
    })
    signal notificationDismissed(string id)
    signal dndChanged(bool enabled)

    ListModel {
        id: popupModel
    }

    function addScreenshot(path) {
        if (!stateLoaded) return;
        const dto = {
            id: "notification-" + nextId++, receivedAt: new Date().toISOString(),
            appName: "Senda", summary: "Captura de pantalla tomada", body: "Pulsa para editar la captura.",
            image: "file://" + encodeURI(path), screenshotPath: path,
            appIcon: "", desktopEntry: "", urgency: 1, expireTimeout: 0,
            actions: [{ identifier: "default", text: "Editar captura" }], hints: []
        };
        unreadNotifications = unreadNotifications.concat([dto]);
        persist();
        if (!dndEnabled) enqueuePopup(dto);
    }

    function dtoFor(notification, serviceId, receivedAt) {
        return {
            "id": serviceId,
            "tracked": Boolean(notification.tracked),
            "lastGeneration": Boolean(notification.lastGeneration),
            "appName": notification.appName || "",
            "desktopEntry": notification.desktopEntry || "",
            "appIcon": notification.appIcon || "",
            "summary": notification.summary || "",
            "body": notification.body || "",
            "image": notification.image || "",
            "urgency": Number(notification.urgency),
            "expireTimeout": Number(notification.expireTimeout),
            "actions": Array.from(notification.actions ?? []).map(action => ({
                "identifier": String(action.identifier || ""),
                "text": String(action.text || "")
            })),
            "hasActionIcons": Boolean(notification.hasActionIcons),
            "resident": Boolean(notification.resident),
            "transient": Boolean(notification.transient),
            "hasInlineReply": Boolean(notification.hasInlineReply),
            "inlineReplyPlaceholder": notification.inlineReplyPlaceholder || "",
            "hints": root.hintDetails(notification.hints),
            "receivedAt": receivedAt
        };
    }

    function printableHintValue(key, value) {
        const lowerKey = String(key).toLowerCase();
        if (/(image|pixmap|icon|data)/.test(lowerKey) && typeof value !== "string")
            return "[contenido multimedia/estructurado disponible]";
        if (value === null || value === undefined)
            return String(value);
        if (["string", "number", "boolean"].includes(typeof value))
            return String(value);
        if (Array.isArray(value))
            return "[" + value.map(item => root.printableHintValue(key, item)).join(", ") + "]";
        try {
            const encoded = JSON.stringify(value);
            return encoded === "{}" ? "[dato estructurado disponible]" : encoded;
        } catch (error) {
            return "[dato estructurado disponible]";
        }
    }

    function hintDetails(hints) {
        const result = [];
        const values = hints ?? {};
        for (const key of Object.keys(values))
            result.push(String(key) + ": " + root.printableHintValue(key, values[key]));
        return result;
    }

    function applicationIconSource(notification) {
        if (!notification)
            return "";

        const desktopEntry = DesktopEntries.heuristicLookup(
            String(notification.desktopEntry || notification.appName || ""));
        const iconNames = [notification.appIcon, desktopEntry?.icon];
        for (const iconValue of iconNames) {
            const icon = String(iconValue || "").trim();
            if (!icon)
                continue;
            if (icon.startsWith("/"))
                return "file://" + encodeURI(icon);
            if (/^(file|image|qrc|data):/i.test(icon))
                return icon;
            const iconSource = Quickshell.iconPath(icon, true);
            if (iconSource)
                return iconSource;
        }
        return "";
    }

    function snapshot() {
        return JSON.parse(JSON.stringify(unreadNotifications));
    }

    function enqueuePopup(notification) {
        const id = String(notification.id);
        hidePopup(id);
        delete pausedPopups[id];
        const focusedMonitor = Hyprland.focusedMonitor;
        let focusedScreen = null;
        if (focusedMonitor) {
            for (let index = 0; index < Quickshell.screens.length; index++) {
                const candidate = Quickshell.screens[index];
                const monitor = Hyprland.monitorFor(candidate);
                if (monitor && monitor.name === focusedMonitor.name) {
                    focusedScreen = candidate;
                    break;
                }
            }
        }
        activePopups.insert(0, {
            "notificationId": id,
            "screenName": focusedScreen ? focusedScreen.name
                : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""),
            "expiresAt": Date.now() + popupLifetimeMs,
            "isFading": false
        });
    }

    function setPopupHovered(id, hovered) {
        const key = String(id);
        for (let index = 0; index < activePopups.count; index++) {
            if (String(activePopups.get(index).notificationId) !== key)
                continue;

            activePopups.setProperty(index, "expiresAt", Date.now() + popupLifetimeMs);
            activePopups.setProperty(index, "isFading", false);
            if (hovered)
                pausedPopups[key] = true;
            else
                delete pausedPopups[key];
            return;
        }
    }

    function notificationForId(id) {
        const key = String(id);
        for (let index = 0; index < unreadNotifications.length; index++) {
            if (String(unreadNotifications[index].id) === key)
                return unreadNotifications[index];
        }
        return null;
    }

    function hidePopup(id) {
        const key = String(id);
        delete pausedPopups[key];
        for (let index = 0; index < activePopups.count; index++) {
            if (String(activePopups.get(index).notificationId) === key) {
                activePopups.remove(index);
                return;
            }
        }
    }

    function expirePopups(now = Date.now()) {
        for (let index = activePopups.count - 1; index >= 0; index--) {
            const id = String(activePopups.get(index).notificationId);
            if (pausedPopups[id])
                continue;

            const remaining = Number(activePopups.get(index).expiresAt) - now;
            if (remaining <= 0)
                activePopups.remove(index);
            else if (remaining <= popupFadeDurationMs && !activePopups.get(index).isFading)
                activePopups.setProperty(index, "isFading", true);
        }
    }

    function persist() {
        revision++;
        if (stateLoaded && !saveInProgress)
            beginSave();

    }

    function beginSave() {
        if (!stateLoaded || saveInProgress)
            return ;

        stateAdapter.version = 1;
        stateAdapter.nextId = nextId;
        stateAdapter.dndEnabled = dndEnabled;
        stateAdapter.notifications = snapshot();
        savingRevision = revision;
        saveInProgress = true;
        stateFile.writeAdapter();
    }

    function onSaved() {
        saveInProgress = false;
        if (savingRevision !== revision)
            Qt.callLater(() => {
            return beginSave();
        });

    }

    function onSaveFailed(error) {
        saveInProgress = false;
        console.warn("Notifications: state save failed:", FileViewError.toString(error));
        saveRetryTimer.restart();
    }

    function validDto(item) {
        return item && typeof item.id === "string" && typeof item.receivedAt === "string" && typeof item.appName === "string" && typeof item.summary === "string" && typeof item.body === "string";
    }

    function onLoaded() {
        const restored = JSON.parse(JSON.stringify(stateAdapter.notifications ?? []));
        unreadNotifications = restored.filter((item) => {
            return validDto(item);
        });
        nextId = Math.max(1, Number(stateAdapter.nextId) || 1);
        dndEnabled = Boolean(stateAdapter.dndEnabled);
        for (let i = 0; i < unreadNotifications.length; i++) {
            const item = unreadNotifications[i];
            if (item._sourceId !== undefined)
                recentServerIds[String(item._sourceId)] = item.id;

        }
        stateLoaded = true;
        // Re-emitted server objects are rebound to their persisted service IDs.
        const carried = notificationServer.trackedNotifications.values;
        for (let i = 0; i < carried.length; i++) {
            const item = carried[i];
            adoptNotification(item, item.lastGeneration);
        }
        if (restored.length !== unreadNotifications.length)
            persist();

    }

    function onLoadFailed(error) {
        if (error === FileViewError.FileNotFound) {
            stateLoaded = true;
            persist();
            return ;
        }
        console.warn("Notifications: state load failed:", FileViewError.toString(error));
        loadRetryTimer.restart();
    }

    function adoptNotification(notification, carriedOver) {
        if (!stateLoaded) {
            // Keep the server object tracked; load completion reconciles it.
            notification.tracked = true;
            return ;
        }
        if (notification.transient) {
            notification.tracked = false;
            return ;
        }
        const serverId = String(notification.id);
        const existingServiceId = recentServerIds[serverId];
        if (carriedOver && existingServiceId) {
            liveNotifications[existingServiceId] = notification;
            notification.tracked = true;
            return ;
        }
        const serviceId = "notification-" + nextId++;
        const receivedAt = new Date().toISOString();
        const dto = dtoFor(notification, serviceId, receivedAt);
        dto._sourceId = notification.id;
        let next = unreadNotifications.slice();
        next.push(dto);
        unreadNotifications = next;
        liveNotifications[serviceId] = notification;
        recentServerIds[serverId] = serviceId;
        notification.tracked = true;
        persist();
        if (!carriedOver && !dndEnabled)
            enqueuePopup(dto);

    }

    function listUnreadJson() {
        return JSON.stringify(unreadNotifications.map((item) => {
            return { "id": item.id };
        }));
    }

    function defaultActionFor(id) {
        const live = liveNotifications[String(id)];
        if (!live || !live.tracked) return null;
        const actions = live.actions ?? [];
        for (let i = 0; i < actions.length; i++) {
            if (String(actions[i].identifier) === "default") return actions[i];
        }
        return null;
    }

    function hasDefaultAction(id) {
        return defaultActionFor(id) !== null;
    }

    function canActivateNotification(id) {
        return Boolean(notificationForId(id)?.screenshotPath) || hasDefaultAction(id) || canFocusApplication(id);
    }

    function desktopEntryForNotification(id) {
        const notification = unreadNotifications.find(item => String(item.id) === String(id));
        const live = liveNotifications[String(id)];
        if (notification?.desktopEntry !== undefined && notification.desktopEntry !== null
            && String(notification.desktopEntry).length > 0)
            return String(notification.desktopEntry);
        return live?.desktopEntry === undefined || live.desktopEntry === null
            ? ""
            : String(live.desktopEntry);
    }

    function canFocusApplication(id) {
        return desktopEntryForNotification(id).length > 0;
    }

    function focusApplication(id) {
        const desktopEntry = desktopEntryForNotification(id);
        if (desktopEntry.length === 0)
            return false;

        const command = [SendaManager.binaryPath, "window", "focus", desktopEntry];
        Quickshell.execDetached(command);
        return true;
    }

    function activate(id) {
        const local = notificationForId(id);
        if (local?.screenshotPath) {
            if (ScreenshotService.openEditor(local.screenshotPath)) dismiss(id);
            return true;
        }
        const action = defaultActionFor(id);
        if (action) {
            action.invoke();
            return true;
        }

        return focusApplication(id);
    }

    function openBodyLink(value) {
        const url = String(value ?? "").trim();
        if (/^https?:\/\/[^\s<>"']+$/i.test(url) || /^mailto:[^\s<>"']+$/i.test(url)) {
            AppRunner.open(url);
            return true;
        }
        return false;
    }

    function dismiss(id) {
        const key = String(id);
        hidePopup(key);
        const index = unreadNotifications.findIndex((item) => {
            return item.id === key;
        });
        if (index < 0)
            return false;

        const next = unreadNotifications.slice();
        next.splice(index, 1);
        unreadNotifications = next;
        notificationDismissed(key);
        const live = liveNotifications[key];
        if (live) {
            delete liveNotifications[key];
            live.dismiss();
        }
        for (const serverId in recentServerIds) {
            if (recentServerIds[serverId] === key)
                delete recentServerIds[serverId];

        }
        persist();
        return true;
    }

    function dismissAll() {
        const notifications = unreadNotifications;
        if (notifications.length === 0)
            return 0;

        const live = liveNotifications;
        const ids = notifications.map((item) => String(item.id));

        unreadNotifications = [];
        liveNotifications = ({});
        recentServerIds = ({});
        pausedPopups = ({});
        activePopups.clear();

        for (let i = 0; i < ids.length; i++) {
            notificationDismissed(ids[i]);
            if (live[ids[i]])
                live[ids[i]].dismiss();
        }

        persist();
        return ids.length;
    }

    function toggleDnd() {
        dndEnabled = !dndEnabled;
        dndChanged(dndEnabled);
        persist();
    }

    NotificationServer {
        id: notificationServer

        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodySupported: true
        imageSupported: true
        onNotification: (notification) => {
            return root.adoptNotification(notification, notification.lastGeneration);
        }
    }

    IpcHandler {
        function listUnread() : string {
            return root.listUnreadJson();
        }

        function dismiss(id: string) : bool {
            return root.dismiss(id);
        }

        function dismissAll() : int {
            return root.dismissAll();
        }

        target: "notifications"
    }

    Process {
        id: stateDirectoryProcess
        command: ["mkdir", "-p", "-m", "700", Quickshell.stateDir]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                secureStateDirectoryProcess.running = true;
            else
                console.warn("Notifications: could not prepare private state directory");
        }
    }

    Process {
        id: secureStateDirectoryProcess
        command: ["chmod", "700", Quickshell.stateDir]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.stateDirectoryReady = true;
            } else {
                console.warn("Notifications: could not secure state directory permissions");
            }
        }
    }

    Component.onCompleted: stateDirectoryProcess.running = true

    FileView {
        id: stateFile

        path: root.stateDirectoryReady ? root.stateFilePath : ""
        atomicWrites: true
        blockWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: root.onLoaded()
        onLoadFailed: (error) => {
            return root.onLoadFailed(error);
        }
        onSaved: root.onSaved()
        onSaveFailed: (error) => {
            return root.onSaveFailed(error);
        }

        JsonAdapter {
            id: stateAdapter

            property int version: 1
            property int nextId: 1
            property bool dndEnabled: false
            property var notifications: []
        }

    }

    Timer {
        id: loadRetryTimer

        interval: 250
        onTriggered: stateFile.reload()
    }

    Timer {
        id: saveRetryTimer

        interval: 1000
        onTriggered: root.beginSave()
    }

    Timer {
        interval: 50
        repeat: true
        running: root.activePopups.count > 0
        onTriggered: root.expirePopups()
    }

}
