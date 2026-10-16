pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property string stateFilePath: Quickshell.stateDir + "/notifications.json"
    property var unreadNotifications: []
    property bool hasNotifications: unreadNotifications.length > 0
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

    signal popupRequested(var notification)
    signal notificationDismissed(string id)
    signal dndChanged(bool enabled)

    function dtoFor(notification, serviceId, receivedAt) {
        return {
            "id": serviceId,
            "appName": notification.appName || "",
            "appIcon": notification.appIcon || "",
            "summary": notification.summary || "",
            "body": notification.body || "",
            "image": notification.image || "",
            "urgency": Number(notification.urgency),
            "receivedAt": receivedAt
        };
    }

    function snapshot() {
        return JSON.parse(JSON.stringify(unreadNotifications));
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
            popupRequested(dto);

    }

    function listUnreadJson() {
        return JSON.stringify(unreadNotifications.map((item) => {
            return { "id": item.id };
        }));
    }

    function dismiss(id) {
        const key = String(id);
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
        const count = unreadNotifications.length;
        const ids = unreadNotifications.map((item) => {
            return item.id;
        });
        for (let i = 0; i < ids.length; i++) dismiss(ids[i])
        return count;
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
        actionsSupported: false
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

}
