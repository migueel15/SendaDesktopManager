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
    property var lastTrackedTask: null
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
    readonly property bool hasLastTrackedTask: lastTrackedTask !== null
    readonly property int lastTrackedTaskId: lastTrackedTask?.id ?? -1
    readonly property bool hasTrackedTask: hasActiveTask || hasLastTrackedTask
    readonly property int trackedTaskId: hasActiveTask ? activeTaskId : lastTrackedTaskId
    readonly property string trackedTaskTitle: hasActiveTask ? activeTask?.title ?? "" : lastTrackedTask?.title ?? ""
    readonly property bool trackedTaskPaused: !hasActiveTask && hasLastTrackedTask
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
            syncLastTrackedTask();
            payload.forEach(task => loadTaskEntries(task.id));
        });
    }

    function loadActiveTask(silent) {
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
        }, undefined, silent !== true);
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
            setLastTrackedTaskById(taskId);
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
            setLastTrackedTaskById(taskId);
            actionInProgress = false;
            actionTaskId = -1;
            setActiveTask(null);
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

    function resumeLastTrackedTask() {
        if (!hasLastTrackedTask || hasActiveTask) {
            return;
        }

        startTask(lastTrackedTask.id);
    }

    function stopTracking(taskId) {
        if (!hasActiveTask) {
            clearLastTrackedTask();
            return;
        }

        const activeId = activeTask.task_id;
        if (taskId !== undefined && taskId !== null && activeId !== taskId) {
            clearLastTrackedTask();
            return;
        }

        if (!ensureConfigured() || actionInProgress) {
            return;
        }

        actionInProgress = true;
        actionTaskId = activeId;

        request("POST", "/tasks/me/active/close", null, () => {
            actionInProgress = false;
            actionTaskId = -1;
            clearLastTrackedTask();
            setActiveTask(null);
            loadTaskEntries(activeId);
        }, (status, responseText) => {
            actionInProgress = false;
            actionTaskId = -1;
            setError(`POST stop task failed (${status})`);
        });
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
            if (lastTrackedTaskId === taskId) {
                clearLastTrackedTask();
            }
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
        const nextActiveTask = task && task.task_id ? task : null;
        const currentTaskId = activeTask?.task_id ?? -1;
        const nextTaskId = nextActiveTask?.task_id ?? -1;

        if (currentTaskId === nextTaskId) {
            if (!nextActiveTask) {
                return;
            }

            setLastTrackedTask(nextActiveTask);

            if (activeTask?.time_entry_id !== nextActiveTask.time_entry_id) {
                activeTask = nextActiveTask;
                activeElapsedSeconds = nextActiveTask.elapsed_seconds ?? 0;
                durationVersion++;
                return;
            }

            if (activeTask?.title !== nextActiveTask.title) {
                activeTask = nextActiveTask;
            }

            const nextElapsedSeconds = Math.max(activeElapsedSeconds, nextActiveTask.elapsed_seconds ?? activeElapsedSeconds);
            if (nextElapsedSeconds !== activeElapsedSeconds) {
                activeElapsedSeconds = nextElapsedSeconds;
                durationVersion++;
            }
            return;
        }

        activeTask = nextActiveTask;
        activeElapsedSeconds = nextActiveTask?.elapsed_seconds ?? 0;
        if (nextActiveTask) {
            setLastTrackedTask(nextActiveTask);
        }
        durationVersion++;
    }

    function findTask(taskId) {
        return tasks.find(task => task.id === taskId) ?? null;
    }

    function normalizeTask(task) {
        if (!task) {
            return null;
        }

        const id = task.id ?? task.task_id;
        if (id === undefined || id === null) {
            return null;
        }

        return {
            "id": id,
            "title": task.title ?? `Task ${id}`,
            "team_id": task.team_id ?? teamId
        };
    }

    function setLastTrackedTask(task) {
        const nextTask = normalizeTask(task);
        if (!nextTask) {
            return;
        }

        if (lastTrackedTask?.id === nextTask.id && lastTrackedTask?.title === nextTask.title && lastTrackedTask?.team_id === nextTask.team_id) {
            return;
        }

        lastTrackedTask = nextTask;
    }

    function setLastTrackedTaskById(taskId) {
        const task = findTask(taskId) ?? (activeTask?.task_id === taskId ? activeTask : null) ?? (lastTrackedTask?.id === taskId ? lastTrackedTask : null) ?? {
            "id": taskId,
            "title": `Task ${taskId}`,
            "team_id": teamId
        };
        setLastTrackedTask(task);
    }

    function syncLastTrackedTask() {
        if (!hasLastTrackedTask) {
            return;
        }

        const task = findTask(lastTrackedTask.id);
        if (task) {
            setLastTrackedTask(task);
        }
    }

    function clearLastTrackedTask() {
        lastTrackedTask = null;
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
        lastTrackedTask = null;
        activeElapsedSeconds = 0;
        entriesByTask = ({});
        setError("Missing Dorlab bearer token");
        return false;
    }

    function request(method, path, body, onSuccess, onError, acceptedStatuses, trackLoading) {
        const okStatuses = acceptedStatuses ?? [200, 201, 204];
        const shouldTrackLoading = trackLoading !== false;
        const xhr = new XMLHttpRequest();

        if (shouldTrackLoading) {
            pendingRequests++;
            loading = true;
        }

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            if (shouldTrackLoading) {
                pendingRequests = Math.max(0, pendingRequests - 1);
                loading = pendingRequests > 0;
            }

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
        onTriggered: root.loadActiveTask(true)
    }
}
