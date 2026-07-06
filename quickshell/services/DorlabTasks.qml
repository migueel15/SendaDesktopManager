pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property string bearerToken: Quickshell.env("DORLAB_API_KEY")
    property int teamId: 1
    property string baseUrl: "https://api.dorlab.net"

    property var tasks: []
    property var activeTask: null
    property var entriesByTask: ({})

    property bool loading: false
    property bool actionInProgress: false
    property bool creatingTask: false
    property int actionTaskId: -1
    property int deletingTaskId: -1
    property string error: ""

    property int activeElapsedSeconds: 0
    property int durationVersion: 0
    property int pendingRequests: 0

    readonly property bool hasActiveTask: activeTask !== null
    readonly property int activeTaskId: activeTask?.task_id ?? -1
    readonly property bool mutationInProgress: actionInProgress || creatingTask || deletingTaskId !== -1

    function refresh() {
        if (!ensureConfigured()) {
            return;
        }

        error = "";
        loadTasks();
        loadActiveTask();
    }

    function loadTasks() {
        if (!ensureConfigured()) {
            return;
        }

        request("GET", `/tasks/teams/${teamId}/tasks`, null, payload => {
            if (!Array.isArray(payload)) {
                tasks = [];
                setError("Unexpected tasks response");
                return;
            }

            tasks = payload;
            payload.forEach(task => loadTaskEntries(task.id));
        });
    }

    function loadActiveTask() {
        if (!ensureConfigured()) {
            return;
        }

        request("GET", "/tasks/me/active", null, payload => {
            setActiveTask(payload);
        }, (status, responseText) => {
            if (status === 404) {
                setActiveTask(null);
                return;
            }

            setError(`GET /tasks/me/active failed (${status})`);
        });
    }

    function loadTaskEntries(taskId) {
        if (!ensureConfigured() || taskId === undefined || taskId === null) {
            return;
        }

        request("GET", `/tasks/teams/${teamId}/tasks/${taskId}/entries`, null, payload => {
            setTaskEntries(taskId, payload?.entries ?? []);
        });
    }

    function startTask(taskId) {
        if (!ensureConfigured() || actionInProgress || hasActiveTask || taskId === undefined || taskId === null) {
            return;
        }

        actionInProgress = true;
        actionTaskId = taskId;

        request("POST", `/tasks/teams/${teamId}/tasks/${taskId}/entries`, null, () => {
            actionInProgress = false;
            actionTaskId = -1;
            loadActiveTask();
            loadTaskEntries(taskId);
        }, (status, responseText) => {
            actionInProgress = false;
            actionTaskId = -1;
            setError(`POST start task failed (${status})`);
        });
    }

    function pauseTask(taskId) {
        if (!ensureConfigured() || actionInProgress || taskId === undefined || taskId === null) {
            return;
        }

        actionInProgress = true;
        actionTaskId = taskId;

        request("POST", "/tasks/me/active/close", null, () => {
            actionInProgress = false;
            actionTaskId = -1;
            loadActiveTask();
            loadTaskEntries(taskId);
        }, (status, responseText) => {
            actionInProgress = false;
            actionTaskId = -1;
            setError(`POST pause task failed (${status})`);
        });
    }

    function pauseActiveTask() {
        if (!hasActiveTask) {
            return;
        }

        pauseTask(activeTask.task_id);
    }

    function createTask(title) {
        const trimmedTitle = (title ?? "").trim();
        if (!ensureConfigured() || mutationInProgress || trimmedTitle.length === 0) {
            return;
        }

        creatingTask = true;
        error = "";

        const body = JSON.stringify({
            "title": trimmedTitle,
            "team_id": teamId
        });

        request("POST", `/tasks/teams/${teamId}/tasks`, body, () => {
            creatingTask = false;
            loadTasks();
        }, (status, responseText) => {
            creatingTask = false;
            setError(`POST create task failed (${status})`);
        });
    }

    function deleteTask(taskId) {
        if (!ensureConfigured() || mutationInProgress || taskId === undefined || taskId === null || activeTaskId === taskId) {
            return;
        }

        deletingTaskId = taskId;
        error = "";

        request("DELETE", `/tasks/teams/${teamId}/tasks/${taskId}`, null, () => {
            deletingTaskId = -1;
            removeTaskEntries(taskId);
            loadTasks();
        }, (status, responseText) => {
            deletingTaskId = -1;
            setError(`DELETE task failed (${status})`);
        });
    }

    function taskTotalSeconds(taskId) {
        const entries = entriesByTask[String(taskId)] ?? [];
        let total = entries.reduce((acc, entry) => acc + (entry.duration_seconds ?? 0), 0);

        if (activeTaskId === taskId) {
            total += activeElapsedSeconds;
        }

        return total;
    }

    function formatDuration(totalSeconds) {
        const seconds = Math.max(0, Math.floor(totalSeconds ?? 0));
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const remainingSeconds = seconds % 60;

        if (hours > 0) {
            return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(remainingSeconds).padStart(2, "0")}`;
        }

        return `${String(minutes).padStart(2, "0")}:${String(remainingSeconds).padStart(2, "0")}`;
    }

    function setActiveTask(task) {
        activeTask = task && task.task_id ? task : null;
        activeElapsedSeconds = activeTask?.elapsed_seconds ?? 0;
        durationVersion++;
    }

    function setTaskEntries(taskId, entries) {
        let nextEntriesByTask = {};
        for (const key in entriesByTask) {
            nextEntriesByTask[key] = entriesByTask[key];
        }

        nextEntriesByTask[String(taskId)] = Array.isArray(entries) ? entries : [];
        entriesByTask = nextEntriesByTask;
        durationVersion++;
    }

    function removeTaskEntries(taskId) {
        let nextEntriesByTask = {};
        const taskKey = String(taskId);
        for (const key in entriesByTask) {
            if (key !== taskKey) {
                nextEntriesByTask[key] = entriesByTask[key];
            }
        }

        entriesByTask = nextEntriesByTask;
        durationVersion++;
    }

    function ensureConfigured() {
        if (bearerToken.trim().length > 0) {
            return true;
        }

        pendingRequests = 0;
        loading = false;
        tasks = [];
        activeTask = null;
        activeElapsedSeconds = 0;
        entriesByTask = ({});
        setError("Missing Dorlab bearer token");
        return false;
    }

    function request(method, path, body, onSuccess, onError, acceptedStatuses) {
        const okStatuses = acceptedStatuses ?? [200, 201, 204];
        const xhr = new XMLHttpRequest();

        pendingRequests++;
        loading = true;

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            pendingRequests = Math.max(0, pendingRequests - 1);
            loading = pendingRequests > 0;

            if (okStatuses.indexOf(xhr.status) === -1) {
                if (onError) {
                    onError(xhr.status, xhr.responseText);
                } else {
                    setError(`${method} ${path} failed (${xhr.status})`);
                }
                return;
            }

            let payload = null;
            if (xhr.responseText && xhr.responseText.length > 0) {
                try {
                    payload = JSON.parse(xhr.responseText);
                } catch (error) {
                    setError(`${method} ${path} returned invalid JSON`);
                    return;
                }
            }

            if (onSuccess) {
                onSuccess(payload, xhr.status);
            }
        };

        xhr.open(method, buildUrl(path));
        xhr.setRequestHeader("Authorization", `Bearer ${bearerToken}`);
        if (body !== null && body !== undefined) {
            xhr.setRequestHeader("Content-Type", "application/json");
        }
        xhr.send(body ?? null);
    }

    function buildUrl(path) {
        const normalizedBaseUrl = baseUrl.endsWith("/") ? baseUrl.slice(0, -1) : baseUrl;
        return `${normalizedBaseUrl}${path}`;
    }

    function setError(message) {
        error = message;
        console.warn("DorlabTasks:", message);
    }

    onBearerTokenChanged: refresh()
    onTeamIdChanged: refresh()

    Component.onCompleted: refresh()

    Timer {
        interval: 1000
        running: root.hasActiveTask
        repeat: true
        onTriggered: {
            root.activeElapsedSeconds++;
            root.durationVersion++;
        }
    }

    Timer {
        interval: 30000
        running: root.bearerToken.trim().length > 0
        repeat: true
        onTriggered: root.loadActiveTask()
    }
}
