pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string bearerToken: Quickshell.env("DORLAB_API_KEY")
    property int workspaceId: 1
    property string workspaceName: "Workspace Personal"
    property string baseUrl: "https://api.dorlab.net"

    property var teams: []
    property var tasksByTeam: ({})
    property var tasks: []
    property var activeTask: null
    property var lastTrackedTask: null
    property var entriesByTask: ({})

    property bool loading: false
    property bool actionInProgress: false
    property bool creatingTeam: false
    property bool creatingTask: false
    property int deletingTeamActionId: -1
    property int creatingTeamId: -1
    property int actionTaskId: -1
    property int actionTeamId: -1
    property int deletingTaskId: -1
    property int deletingTeamId: -1
    property int updatingTaskId: -1
    property int updatingTeamId: -1
    property string error: ""

    property int activeElapsedSeconds: 0
    property int durationVersion: 0
    property int layoutVersion: 0
    property int pendingRequests: 0
    property string layoutLoadState: "loading"
    property string teamsLoadState: "loading"
    property string layoutSaveState: "clean"
    property var layoutWorkspaces: ({})
    property int layoutRevision: 0
    property int savingLayoutRevision: -1
    property int layoutLoadRetryCount: 0
    property int layoutSaveRetryCount: 0
    property bool layoutSaveInProgress: false
    property bool serviceReady: false

    readonly property bool hasActiveTask: activeTask !== null
    readonly property int activeTaskId: activeTask?.task_id ?? -1
    readonly property int activeTeamId: activeTask?.team_id ?? -1
    readonly property bool hasLastTrackedTask: lastTrackedTask !== null
    readonly property int lastTrackedTaskId: lastTrackedTask?.id ?? -1
    readonly property int lastTrackedTeamId: lastTrackedTask?.team_id ?? -1
    readonly property bool hasTrackedTask: hasActiveTask || hasLastTrackedTask
    readonly property int trackedTaskId: hasActiveTask ? activeTaskId : lastTrackedTaskId
    readonly property int trackedTeamId: hasActiveTask ? activeTeamId : lastTrackedTeamId
    readonly property string trackedTaskTitle: hasActiveTask ? taskTitle(activeTask) : taskTitle(lastTrackedTask)
    readonly property bool trackedTaskPaused: !hasActiveTask && hasLastTrackedTask
    readonly property bool mutationInProgress: actionInProgress || creatingTeam || creatingTask || deletingTeamActionId !== -1 || deletingTaskId !== -1 || updatingTaskId !== -1
    readonly property string layoutFilePath: Quickshell.stateDir + "/dorlab-tasks-layout.json"

    function refresh() {
        if (!ensureConfigured()) {
            return;
        }

        error = "";
        loadTeams();
        loadActiveTask();
    }

    function loadTeams() {
        if (!ensureConfigured()) {
            return;
        }

        teamsLoadState = "loading";
        request("GET", `/tasks/workspaces/${workspaceId}/teams`, null, payload => {
            if (!Array.isArray(payload)) {
                teams = [];
                tasksByTeam = ({});
                tasks = [];
                teamsLoadState = "error";
                setError("Unexpected teams response");
                return;
            }

            teams = payload;
            const nextTasksByTeam = {};
            payload.forEach(team => nextTasksByTeam[String(team.id)] = tasksByTeam[String(team.id)] ?? []);
            tasksByTeam = nextTasksByTeam;
            rebuildTasks();
            syncLastTrackedTask();
            payload.forEach(team => loadTeamTasks(team));

            // Publish the ready state only after the complete teams snapshot has
            // been installed. This prevents reconciliation from observing a
            // half-updated model during startup.
            teamsLoadState = "loaded";
            Qt.callLater(() => reconcileTeamLayout());
        }, status => {
            teamsLoadState = "error";
            setError(`GET teams failed (${status})`);
        });
    }

    function loadTeamTasks(team) {
        if (!ensureConfigured() || !team || team.id === undefined || team.id === null) {
            return;
        }

        request("GET", `/tasks/teams/${team.id}/tasks`, null, payload => {
            if (!Array.isArray(payload)) {
                setError(`Unexpected tasks response for team ${team.id}`);
                return;
            }

            const teamTasks = payload.map(task => normalizeTask(task, team)).filter(task => task !== null);
            setTeamTasks(team.id, teamTasks);
            syncLastTrackedTask();
            teamTasks.forEach(task => loadTaskEntries(task.id, task.team_id));
        });
    }

    function createTeam(name) {
        const trimmedName = (name ?? "").trim();
        if (!ensureConfigured() || mutationInProgress || trimmedName.length === 0) {
            return;
        }

        creatingTeam = true;
        error = "";

        const body = JSON.stringify({
            "name": trimmedName,
            "workspace_id": workspaceId
        });

        request("POST", `/tasks/workspaces/${workspaceId}/teams`, body, () => {
            creatingTeam = false;
            loadTeams();
        }, (status, responseText) => {
            creatingTeam = false;
            setError(`POST create team failed (${status})`);
        });
    }

    function deleteTeam(teamId) {
        if (!ensureConfigured() || mutationInProgress || teamId === undefined || teamId === null || activeTeamId === teamId) {
            return;
        }

        deletingTeamActionId = teamId;
        error = "";

        request("DELETE", `/tasks/workspaces/${workspaceId}/teams/${teamId}`, null, () => {
            deletingTeamActionId = -1;
            if (lastTrackedTeamId === teamId) {
                clearLastTrackedTask();
            }
            removeTeamLocal(teamId);
            loadTeams();
        }, (status, responseText) => {
            deletingTeamActionId = -1;
            setError(`DELETE team failed (${status})`);
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

    function loadTaskEntries(taskId, teamId) {
        if (!ensureConfigured() || taskId === undefined || taskId === null || teamId === undefined || teamId === null) {
            return;
        }

        request("GET", `/tasks/teams/${teamId}/tasks/${taskId}/entries`, null, payload => {
            const entries = Array.isArray(payload) ? payload : payload?.entries ?? [];
            setTaskEntries(teamId, taskId, entries);
        });
    }

    function startTask(taskOrId, teamId) {
        const task = resolveTask(taskOrId, teamId);
        if (!ensureConfigured() || actionInProgress || hasActiveTask || !task) {
            return;
        }

        actionInProgress = true;
        actionTaskId = task.id;
        actionTeamId = task.team_id;

        request("POST", `/tasks/teams/${task.team_id}/tasks/${task.id}/entries`, null, () => {
            setLastTrackedTask(task);
            actionInProgress = false;
            actionTaskId = -1;
            actionTeamId = -1;
            loadActiveTask();
            loadTaskEntries(task.id, task.team_id);
        }, (status, responseText) => {
            actionInProgress = false;
            actionTaskId = -1;
            actionTeamId = -1;
            setError(`POST start task failed (${status})`);
        });
    }

    function pauseTask(taskOrId, teamId) {
        const task = resolveTask(taskOrId, teamId) ?? resolveTask(activeTask?.task_id, activeTask?.team_id);
        if (!ensureConfigured() || actionInProgress || !task) {
            return;
        }

        actionInProgress = true;
        actionTaskId = task.id;
        actionTeamId = task.team_id;

        request("POST", "/tasks/me/active/close", null, () => {
            setLastTrackedTask(task);
            actionInProgress = false;
            actionTaskId = -1;
            actionTeamId = -1;
            setActiveTask(null);
            loadTaskEntries(task.id, task.team_id);
        }, (status, responseText) => {
            actionInProgress = false;
            actionTaskId = -1;
            actionTeamId = -1;
            setError(`POST pause task failed (${status})`);
        });
    }

    function pauseActiveTask() {
        if (!hasActiveTask) {
            return;
        }

        pauseTask(activeTask.task_id, activeTask.team_id);
    }

    function resumeLastTrackedTask() {
        if (!hasLastTrackedTask || hasActiveTask) {
            return;
        }

        startTask(lastTrackedTask);
    }

    function stopTracking(taskOrId, teamId) {
        if (!hasActiveTask) {
            clearLastTrackedTask();
            return;
        }

        const task = resolveTask(taskOrId, teamId) ?? resolveTask(activeTask.task_id, activeTask.team_id);
        const activeId = activeTask.task_id;
        const activeTeam = activeTask.team_id;
        if (task && (task.id !== activeId || task.team_id !== activeTeam)) {
            clearLastTrackedTask();
            return;
        }

        if (!ensureConfigured() || actionInProgress) {
            return;
        }

        actionInProgress = true;
        actionTaskId = activeId;
        actionTeamId = activeTeam;

        request("POST", "/tasks/me/active/close", null, () => {
            actionInProgress = false;
            actionTaskId = -1;
            actionTeamId = -1;
            clearLastTrackedTask();
            setActiveTask(null);
            loadTaskEntries(activeId, activeTeam);
        }, (status, responseText) => {
            actionInProgress = false;
            actionTaskId = -1;
            actionTeamId = -1;
            setError(`POST stop task failed (${status})`);
        });
    }

    function createTask(teamId, title) {
        const trimmedTitle = (title ?? "").trim();
        if (!ensureConfigured() || mutationInProgress || teamId === undefined || teamId === null || trimmedTitle.length === 0) {
            return;
        }

        creatingTask = true;
        creatingTeamId = teamId;
        error = "";

        const body = JSON.stringify({
            "title": trimmedTitle,
            "team_id": teamId
        });

        request("POST", `/tasks/teams/${teamId}/tasks`, body, () => {
            creatingTask = false;
            creatingTeamId = -1;
            loadTeamTasks(findTeam(teamId) ?? {
                "id": teamId,
                "name": `Team ${teamId}`
            });
        }, (status, responseText) => {
            creatingTask = false;
            creatingTeamId = -1;
            setError(`POST create task failed (${status})`);
        });
    }

    function deleteTask(taskOrId, teamId) {
        const task = resolveTask(taskOrId, teamId);
        if (!ensureConfigured() || mutationInProgress || !task || isActiveTask(task)) {
            return;
        }

        deletingTaskId = task.id;
        deletingTeamId = task.team_id;
        error = "";

        request("DELETE", `/tasks/teams/${task.team_id}/tasks/${task.id}`, null, () => {
            deletingTaskId = -1;
            deletingTeamId = -1;
            if (lastTrackedTaskId === task.id && lastTrackedTeamId === task.team_id) {
                clearLastTrackedTask();
            }
            removeTaskEntries(task.team_id, task.id);
            loadTeamTasks(findTeam(task.team_id) ?? {
                "id": task.team_id,
                "name": task.team_name ?? `Team ${task.team_id}`
            });
        }, (status, responseText) => {
            deletingTaskId = -1;
            deletingTeamId = -1;
            setError(`DELETE task failed (${status})`);
        });
    }

    function updateTask(taskOrId, patch, teamId) {
        const task = resolveTask(taskOrId, teamId);
        if (!ensureConfigured() || mutationInProgress || !task || !patch) {
            return;
        }

        const bodyData = {};
        if (patch.title !== undefined) {
            const trimmedTitle = String(patch.title ?? "").trim();
            if (trimmedTitle.length > 0) {
                bodyData.title = trimmedTitle;
            }
        }
        if (patch.completed !== undefined) {
            bodyData.completed = !!patch.completed;
        }

        if (Object.keys(bodyData).length === 0) {
            return;
        }

        updatingTaskId = task.id;
        updatingTeamId = task.team_id;
        error = "";

        request("PATCH", `/tasks/teams/${task.team_id}/tasks/${task.id}`, JSON.stringify(bodyData), payload => {
            updatingTaskId = -1;
            updatingTeamId = -1;
            const updatedTask = normalizeTask(payload, findTeam(task.team_id));
            if (updatedTask) {
                replaceTask(updatedTask);
            }
        }, (status, responseText) => {
            updatingTaskId = -1;
            updatingTeamId = -1;
            setError(`PATCH task failed (${status})`);
        });
    }

    function toggleTaskCompleted(taskOrId, teamId) {
        const task = resolveTask(taskOrId, teamId);
        if (!task || isActiveTask(task)) {
            return;
        }

        updateTask(task, {
            "completed": !task.completed
        });
    }

    function renameTask(taskOrId, title, teamId) {
        updateTask(taskOrId, {
            "title": title
        }, teamId);
    }

    function tasksForTeam(teamId) {
        return tasksByTeam[String(teamId)] ?? [];
    }

    function normalizedWorkspaceLayout(workspaces) {
        const saved = workspaces[String(workspaceId)] ?? {};
        return {
            "teamOrder": normalizedTeamIds(saved.teamOrder),
            "hiddenTeamIds": normalizedTeamIds(saved.hiddenTeamIds),
            "collapsedTeamIds": normalizedTeamIds(saved.collapsedTeamIds)
        };
    }

    function workspaceLayout() {
        layoutVersion;
        return normalizedWorkspaceLayout(layoutWorkspaces);
    }

    function normalizedTeamIds(values) {
        if (values === undefined || values === null || typeof values.length !== "number") {
            return [];
        }

        const result = [];
        for (let index = 0; index < values.length; index++) {
            const value = values[index];
            const id = String(value);
            if (id.length > 0 && result.indexOf(id) === -1) {
                result.push(id);
            }
        }
        return result;
    }

    function orderedTeams(includeHidden) {
        const layout = workspaceLayout();
        const teamsById = {};
        teams.forEach(team => teamsById[String(team.id)] = team);

        const result = [];
        const addedIds = [];
        layout.teamOrder.forEach(id => {
            if (teamsById[id] && addedIds.indexOf(id) === -1) {
                result.push(teamsById[id]);
                addedIds.push(id);
            }
        });
        teams.forEach(team => {
            const id = String(team.id);
            if (addedIds.indexOf(id) === -1) {
                result.push(team);
                addedIds.push(id);
            }
        });

        if (includeHidden === true) {
            return result;
        }

        return result.filter(team => !isTeamHidden(team.id) || sameId(team.id, activeTeamId));
    }

    function hiddenTeams() {
        return orderedTeams(true).filter(team => isTeamHidden(team.id) && !sameId(team.id, activeTeamId));
    }

    function isTeamHidden(teamId) {
        return workspaceLayout().hiddenTeamIds.indexOf(String(teamId)) !== -1;
    }

    function isTeamCollapsed(teamId) {
        return workspaceLayout().collapsedTeamIds.indexOf(String(teamId)) !== -1;
    }

    function toggleTeamCollapsed(teamId) {
        const layout = workspaceLayout();
        const id = String(teamId);
        const collapsedIds = layout.collapsedTeamIds.slice();
        const index = collapsedIds.indexOf(id);
        if (index === -1) {
            collapsedIds.push(id);
        } else {
            collapsedIds.splice(index, 1);
        }
        updateWorkspaceLayout({
            "collapsedTeamIds": collapsedIds
        });
    }

    function setTeamCollapsed(teamId, collapsed) {
        if (isTeamCollapsed(teamId) !== collapsed) {
            toggleTeamCollapsed(teamId);
        }
    }

    function setTeamHidden(teamId, hidden) {
        if (hidden && sameId(teamId, activeTeamId)) {
            return;
        }

        const layout = workspaceLayout();
        const id = String(teamId);
        const hiddenIds = layout.hiddenTeamIds.slice();
        const index = hiddenIds.indexOf(id);
        if (hidden && index === -1) {
            hiddenIds.push(id);
        } else if (!hidden && index !== -1) {
            hiddenIds.splice(index, 1);
        } else {
            return;
        }
        updateWorkspaceLayout({
            "hiddenTeamIds": hiddenIds
        });
    }

    function moveVisibleTeam(teamId, newVisibleIndex) {
        const sourceId = String(teamId);
        const visibleIds = orderedTeams(false).map(team => String(team.id));
        const currentIndex = visibleIds.indexOf(sourceId);
        if (currentIndex === -1) {
            return;
        }

        visibleIds.splice(currentIndex, 1);
        const targetIndex = Math.max(0, Math.min(visibleIds.length, Number(newVisibleIndex)));
        visibleIds.splice(targetIndex, 0, sourceId);

        const layout = workspaceLayout();
        const effectivelyHiddenIds = layout.hiddenTeamIds.filter(id => !sameId(id, activeTeamId));
        let visibleIndex = 0;
        const nextOrder = orderedTeams(true).map(team => {
            const id = String(team.id);
            if (effectivelyHiddenIds.indexOf(id) !== -1) {
                return id;
            }
            return visibleIds[visibleIndex++];
        });

        updateWorkspaceLayout({
            "teamOrder": nextOrder
        });
    }

    function updateWorkspaceLayout(patch) {
        const workspaces = Object.assign({}, layoutWorkspaces);
        const workspaceKey = String(workspaceId);
        const current = workspaceLayout();
        workspaces[workspaceKey] = {
            "teamOrder": patch.teamOrder ?? current.teamOrder,
            "hiddenTeamIds": patch.hiddenTeamIds ?? current.hiddenTeamIds,
            "collapsedTeamIds": patch.collapsedTeamIds ?? current.collapsedTeamIds
        };
        layoutWorkspaces = workspaces;
        layoutVersion++;
        layoutRevision++;
        requestLayoutSave();
    }

    function reconciledTeamLayout(layout) {
        const currentIds = teams.map(team => String(team.id));
        const order = layout.teamOrder.filter(id => currentIds.indexOf(id) !== -1);
        currentIds.forEach(id => {
            if (order.indexOf(id) === -1) {
                order.push(id);
            }
        });
        const hiddenIds = layout.hiddenTeamIds.filter(id => currentIds.indexOf(id) !== -1);
        const collapsedIds = layout.collapsedTeamIds.filter(id => currentIds.indexOf(id) !== -1);

        return {
            "teamOrder": order,
            "hiddenTeamIds": hiddenIds,
            "collapsedTeamIds": collapsedIds
        };
    }

    function reconcileTeamLayout() {
        if (teamsLoadState !== "loaded" || (layoutLoadState !== "loaded" && layoutLoadState !== "missing")) {
            return;
        }

        const layout = workspaceLayout();
        const reconciled = reconciledTeamLayout(layout);
        if (JSON.stringify(reconciled) !== JSON.stringify(layout)) {
            updateWorkspaceLayout(reconciled);
        } else if (layoutLoadState === "missing") {
            requestLayoutSave();
        }
    }

    function requestLayoutSave() {
        if (layoutLoadState === "loading" || layoutLoadState === "error") {
            return;
        }

        layoutSaveState = "dirty";
        layoutSaveRetryCount = 0;
        layoutSaveRetryTimer.stop();
        if (!layoutSaveInProgress) {
            Qt.callLater(() => beginLayoutSave());
        }
    }

    function beginLayoutSave() {
        if (layoutSaveInProgress || layoutSaveState === "clean" || layoutLoadState === "loading" || layoutLoadState === "error") {
            return;
        }

        layoutAdapter.version = 1;
        layoutAdapter.workspaces = JSON.parse(JSON.stringify(layoutWorkspaces));
        savingLayoutRevision = layoutRevision;
        layoutSaveInProgress = true;
        layoutSaveState = "saving";
        layoutFile.writeAdapter();
    }

    function handleLayoutSaved() {
        layoutSaveInProgress = false;
        layoutSaveRetryCount = 0;
        if (layoutLoadState === "missing") {
            layoutLoadState = "loaded";
        }

        if (savingLayoutRevision === layoutRevision) {
            layoutSaveState = "clean";
        } else {
            layoutSaveState = "dirty";
            Qt.callLater(() => beginLayoutSave());
        }
    }

    function handleLayoutSaveFailed(error) {
        layoutSaveInProgress = false;
        layoutSaveState = "error";
        layoutSaveRetryCount++;
        console.warn("DorlabTasks: layout save failed:", FileViewError.toString(error));
        if (layoutSaveRetryCount <= 3) {
            layoutSaveRetryTimer.restart();
        }
    }

    function handleLayoutLoaded() {
        layoutLoadRetryTimer.stop();
        layoutLoadRetryCount = 0;
        // JsonAdapter exposes JSON arrays as QML sequences. Deep-converting the
        // payload gives the service ordinary JavaScript arrays, which are safe
        // to normalize, compare and reorder.
        const loadedWorkspaces = JSON.parse(JSON.stringify(layoutAdapter.workspaces ?? {}));
        layoutWorkspaces = loadedWorkspaces;
        layoutSaveState = "clean";
        layoutVersion++;

        // Keep this assignment last: changing it unlocks reconciliation.
        layoutLoadState = "loaded";
        Qt.callLater(() => reconcileTeamLayout());
    }

    function handleLayoutLoadFailed(error) {
        if (error === FileViewError.FileNotFound && layoutLoadRetryCount < 3) {
            layoutLoadRetryCount++;
            layoutLoadRetryTimer.restart();
            return;
        }

        layoutVersion++;
        if (error === FileViewError.FileNotFound) {
            layoutWorkspaces = ({});
            layoutSaveState = "clean";
            // As above, the ready state is the final part of the snapshot commit.
            layoutLoadState = "missing";
            Qt.callLater(() => reconcileTeamLayout());
            return;
        }

        layoutLoadState = "error";
        layoutSaveState = "error";
        console.warn("DorlabTasks: layout load failed:", FileViewError.toString(error));
    }

    function pendingTasksForTeam(teamId, query) {
        return filteredTasksForTeam(teamId, false, query);
    }

    function completedTasksForTeam(teamId, query) {
        return filteredTasksForTeam(teamId, true, query);
    }

    function normalizeSearchText(value) {
        let normalized = String(value ?? "").trim().toLowerCase();

        // Treat accents as their base character and ignore separators so that,
        // for example, "ref loader" and "ref-loader" behave like "refloader".
        if (typeof normalized.normalize === "function") {
            normalized = normalized.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
        }

        return normalized.replace(/[\s._\-/]+/g, "");
    }

    function fuzzyMatches(value, normalizedQuery) {
        const candidate = normalizeSearchText(value);
        if (normalizedQuery.length === 0) {
            return true;
        }

        let candidateIndex = 0;
        for (let queryIndex = 0; queryIndex < normalizedQuery.length; queryIndex += 1) {
            candidateIndex = candidate.indexOf(normalizedQuery[queryIndex], candidateIndex);
            if (candidateIndex === -1) {
                return false;
            }
            candidateIndex += 1;
        }

        return true;
    }

    function filteredTasksForTeam(teamId, completed, query) {
        const normalizedQuery = normalizeSearchText(query);
        return tasksForTeam(teamId).filter(task => {
            if (!!task.completed !== completed) {
                return false;
            }

            if (normalizedQuery.length === 0) {
                return true;
            }

            return fuzzyMatches(task.title, normalizedQuery) || fuzzyMatches(task.team_name, normalizedQuery);
        }).sort((a, b) => compareTasksByLastEntry(a, b));
    }

    function compareTasksByLastEntry(a, b) {
        const bLast = taskLastEntryMs(b);
        const aLast = taskLastEntryMs(a);
        if (bLast !== aLast) {
            return bLast - aLast;
        }

        return (a.title ?? "").localeCompare(b.title ?? "");
    }

    function taskLastEntryMs(task) {
        if (!task) {
            return 0;
        }

        if (sameId(activeTeamId, task.team_id) && sameId(activeTaskId, task.id)) {
            return Date.now();
        }

        const entries = taskEntries(task.team_id, task.id);
        let latest = 0;
        entries.forEach(entry => {
            const value = entryTimestampMs(entry);
            if (!isNaN(value) && value > latest) {
                latest = value;
            }
        });
        return latest;
    }

    function taskTotalSeconds(teamId, taskId) {
        const entries = taskEntries(teamId, taskId);
        let total = entries.reduce((acc, entry) => acc + entryDurationSeconds(entry), 0);

        if (sameId(activeTeamId, teamId) && sameId(activeTaskId, taskId)) {
            total += activeElapsedSeconds;
        }

        return total;
    }

    function entryDurationSeconds(entry) {
        const duration = Number(entry?.duration_seconds);
        if (!isNaN(duration) && isFinite(duration) && duration > 0) {
            return duration;
        }

        const startedAt = parseDateMs(entry?.started_at);
        const endedAt = parseDateMs(entry?.ended_at);
        if (startedAt > 0 && endedAt > startedAt) {
            return Math.floor((endedAt - startedAt) / 1000);
        }

        return 0;
    }

    function entryTimestampMs(entry) {
        return Math.max(parseDateMs(entry?.ended_at), parseDateMs(entry?.started_at));
    }

    function parseDateMs(value) {
        if (!value) {
            return 0;
        }

        const normalized = String(value).replace(/(\.\d{3})\d+/, "$1");
        const parsed = Date.parse(normalized);
        return isNaN(parsed) ? 0 : parsed;
    }

    function taskTitle(task) {
        const title = String(task?.title ?? task?.name ?? task?.task_title ?? task?.taskTitle ?? task?.Title ?? "").trim();
        if (title.length > 0) {
            return title;
        }

        const id = task?.id ?? task?.task_id ?? "";
        return `Task ${id}`.trim();
    }

    function taskEntriesLabel(task) {
        if (!task) {
            return "00:00";
        }

        return formatDuration(taskTotalSeconds(task.team_id, task.id));
    }

    function taskLastEntryLabel(task) {
        const lastMs = taskLastEntryMs(task);
        if (lastMs <= 0) {
            return "Sin time entries";
        }

        return Qt.formatDateTime(new Date(lastMs), "dd MMM HH:mm");
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
        const currentTeamId = activeTask?.team_id ?? -1;
        const nextTaskId = nextActiveTask?.task_id ?? -1;
        const nextTeamId = nextActiveTask?.team_id ?? -1;

        if (currentTaskId === nextTaskId && currentTeamId === nextTeamId) {
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

    function setTeamTasks(teamId, teamTasks) {
        let nextTasksByTeam = {};
        for (const key in tasksByTeam) {
            nextTasksByTeam[key] = tasksByTeam[key];
        }

        nextTasksByTeam[String(teamId)] = Array.isArray(teamTasks) ? teamTasks : [];
        tasksByTeam = nextTasksByTeam;
        rebuildTasks();
        durationVersion++;
    }

    function replaceTask(updatedTask) {
        const teamKey = String(updatedTask.team_id);
        const teamTasks = tasksByTeam[teamKey] ?? [];
        const nextTeamTasks = teamTasks.map(task => sameId(task.id, updatedTask.id) ? updatedTask : task);
        setTeamTasks(updatedTask.team_id, nextTeamTasks);

        if (sameId(lastTrackedTaskId, updatedTask.id) && sameId(lastTrackedTeamId, updatedTask.team_id)) {
            setLastTrackedTask(updatedTask);
        }

        if (sameId(activeTaskId, updatedTask.id) && sameId(activeTeamId, updatedTask.team_id)) {
            activeTask = {
                "task_id": activeTask.task_id,
                "title": updatedTask.title,
                "team_id": activeTask.team_id,
                "time_entry_id": activeTask.time_entry_id,
                "member_id": activeTask.member_id,
                "started_at": activeTask.started_at,
                "elapsed_seconds": activeTask.elapsed_seconds
            };
        }
    }

    function rebuildTasks() {
        const nextTasks = [];
        teams.forEach(team => {
            const teamTasks = tasksByTeam[String(team.id)] ?? [];
            teamTasks.forEach(task => nextTasks.push(task));
        });
        tasks = nextTasks;
    }

    function findTeam(teamId) {
        return teams.find(team => sameId(team.id, teamId)) ?? null;
    }

    function isDeletingTeam(teamId) {
        return sameId(deletingTeamActionId, teamId);
    }

    function teamName(team) {
        return team?.name ?? team?.title ?? `Team ${team?.id ?? ""}`;
    }

    function findTask(taskId, teamId) {
        if (teamId !== undefined && teamId !== null) {
            return tasks.find(task => sameId(task.id, taskId) && sameId(task.team_id, teamId)) ?? null;
        }

        return tasks.find(task => sameId(task.id, taskId)) ?? null;
    }

    function resolveTask(taskOrId, teamId) {
        if (taskOrId === undefined || taskOrId === null) {
            return null;
        }

        if (typeof taskOrId === "object") {
            return normalizeTask(taskOrId, findTeam(taskOrId.team_id));
        }

        return findTask(taskOrId, teamId) ?? (teamId !== undefined && teamId !== null ? normalizeTask({
                "id": taskOrId,
                "team_id": teamId,
                "title": `Task ${taskOrId}`
            }, findTeam(teamId)) : null);
    }

    function normalizeTask(task, team) {
        if (!task) {
            return null;
        }

        const id = normalizeId(task.id ?? task.task_id);
        const resolvedTeamId = normalizeId(task.team_id ?? team?.id);
        if (id === undefined || id === null || resolvedTeamId === undefined || resolvedTeamId === null) {
            return null;
        }

        const resolvedTeam = team ?? findTeam(resolvedTeamId);
        return {
            "id": id,
            "title": root.taskTitle({
                "id": id,
                "title": task.title
            }),
            "team_id": resolvedTeamId,
            "completed": task.completed ?? false,
            "team_name": task.team_name ?? teamName(resolvedTeam ?? {
                "id": resolvedTeamId
            })
        };
    }

    function setLastTrackedTask(task) {
        const nextTask = normalizeTask(task, findTeam(task?.team_id));
        if (!nextTask) {
            return;
        }

        if (sameId(lastTrackedTask?.id, nextTask.id) && sameId(lastTrackedTask?.team_id, nextTask.team_id) && lastTrackedTask?.title === nextTask.title && lastTrackedTask?.team_name === nextTask.team_name) {
            return;
        }

        lastTrackedTask = nextTask;
    }

    function syncLastTrackedTask() {
        if (!hasLastTrackedTask) {
            return;
        }

        const task = findTask(lastTrackedTask.id, lastTrackedTask.team_id);
        if (task) {
            setLastTrackedTask(task);
        }
    }

    function clearLastTrackedTask() {
        lastTrackedTask = null;
    }

    function removeTeamLocal(teamId) {
        teams = teams.filter(team => team.id !== teamId);

        let nextTasksByTeam = {};
        for (const key in tasksByTeam) {
            if (key !== String(teamId)) {
                nextTasksByTeam[key] = tasksByTeam[key];
            }
        }
        tasksByTeam = nextTasksByTeam;

        let nextEntriesByTask = {};
        const keyPrefix = `${teamId}:`;
        for (const key in entriesByTask) {
            if (!key.startsWith(keyPrefix)) {
                nextEntriesByTask[key] = entriesByTask[key];
            }
        }
        entriesByTask = nextEntriesByTask;

        rebuildTasks();
        durationVersion++;
        reconcileTeamLayout();
    }

    function isActiveTask(task) {
        return !!task && sameId(activeTaskId, task.id) && sameId(activeTeamId, task.team_id);
    }

    function taskKey(teamId, taskId) {
        return `${teamId}:${taskId}`;
    }

    function taskEntries(teamId, taskId) {
        return entriesByTask[taskKey(teamId, taskId)] ?? entriesByTask[String(taskId)] ?? [];
    }

    function normalizeId(value) {
        if (value === undefined || value === null || value === "") {
            return null;
        }

        const numericValue = Number(value);
        return isNaN(numericValue) || !isFinite(numericValue) ? value : numericValue;
    }

    function sameId(left, right) {
        if (left === undefined || left === null || right === undefined || right === null) {
            return false;
        }

        return String(left) === String(right);
    }

    function setTaskEntries(teamId, taskId, entries) {
        let nextEntriesByTask = {};
        for (const key in entriesByTask) {
            nextEntriesByTask[key] = entriesByTask[key];
        }

        const normalizedEntries = Array.isArray(entries) ? entries : [];
        nextEntriesByTask[taskKey(teamId, taskId)] = normalizedEntries;
        nextEntriesByTask[String(taskId)] = normalizedEntries;

        const entryTaskId = normalizeId(normalizedEntries.find(entry => entry?.task_id !== undefined && entry?.task_id !== null)?.task_id);
        if (entryTaskId !== null) {
            nextEntriesByTask[taskKey(teamId, entryTaskId)] = normalizedEntries;
            nextEntriesByTask[String(entryTaskId)] = normalizedEntries;
        }
        entriesByTask = nextEntriesByTask;
        durationVersion++;
    }

    function removeTaskEntries(teamId, taskId) {
        let nextEntriesByTask = {};
        const keyToRemove = taskKey(teamId, taskId);
        for (const key in entriesByTask) {
            if (key !== keyToRemove) {
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
        teams = [];
        tasksByTeam = ({});
        tasks = [];
        activeTask = null;
        lastTrackedTask = null;
        activeElapsedSeconds = 0;
        entriesByTask = ({});
        teamsLoadState = "error";
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

    onBearerTokenChanged: {
        if (serviceReady) {
            teamsLoadState = "loading";
            refresh();
        }
    }
    onWorkspaceIdChanged: {
        if (serviceReady) {
            teamsLoadState = "loading";
            refresh();
        }
    }

    Component.onCompleted: {
        serviceReady = true;
        refresh();
    }

    FileView {
        id: layoutFile

        path: root.layoutFilePath
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: root.handleLayoutLoaded()
        onLoadFailed: error => root.handleLayoutLoadFailed(error)
        onSaved: root.handleLayoutSaved()
        onSaveFailed: error => root.handleLayoutSaveFailed(error)

        JsonAdapter {
            id: layoutAdapter

            property int version: 1
            property var workspaces: ({})
        }
    }

    Timer {
        id: layoutLoadRetryTimer

        interval: 100
        onTriggered: layoutFile.reload()
    }

    Timer {
        id: layoutSaveRetryTimer

        interval: 1000
        onTriggered: root.beginLayoutSave()
    }

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
