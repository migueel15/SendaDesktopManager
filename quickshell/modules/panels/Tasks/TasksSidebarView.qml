import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

Item {
    id: root

    property string searchText: ""
    property bool showSearch: false
    property bool showCreateTeamForm: false
    property bool showHiddenTeams: false
    property int activeCreateTaskTeamId: -1
    property string draggedTeamId: ""
    property int dragTargetIndex: -1
    property var hiddenTeams: {
        DorlabTasks.layoutVersion;
        DorlabTasks.teams;
        return DorlabTasks.hiddenTeams();
    }

    function openSearch() {
        showSearch = true;
        Qt.callLater(() => searchBox.focusInput());
    }

    function restorePanelFocus() {
        Qt.callLater(() => {
            if (OverlayService.isOpen("tasks") && !root.showSearch) {
                root.forceActiveFocus();
            }
        });
    }

    function closeSearch() {
        searchText = "";
        showSearch = false;
        searchBox.releaseFocus();
        restorePanelFocus();
    }

    function focusTaskCreateInput(teamId) {
        for (let index = 0; index < teamRepeater.count; index += 1) {
            const item = teamRepeater.itemAt(index);
            if (item && DorlabTasks.sameId(item.modelData.id, teamId)) {
                item.focusCreateInput();
                return;
            }
        }
    }

    function updateDragTarget(slot) {
        const draggedCenter = slot.y + slot.cardOffset + slot.height / 2;
        let targetIndex = 0;
        for (let index = 0; index < teamRepeater.count; index += 1) {
            const item = teamRepeater.itemAt(index);
            if (item && item !== slot && draggedCenter > item.y + item.height / 2) {
                targetIndex += 1;
            }
        }
        dragTargetIndex = targetIndex;
    }

    function finishTeamDrag(slot) {
        const teamId = slot.modelData.id;
        const targetIndex = dragTargetIndex;
        slot.resetCardPosition();
        teamsFlickable.interactive = true;
        draggedTeamId = "";
        dragTargetIndex = -1;
        Qt.callLater(() => DorlabTasks.moveVisibleTeam(teamId, targetIndex));
    }

    function cancelTeamDrag(slot) {
        slot.resetCardPosition();
        teamsFlickable.interactive = true;
        draggedTeamId = "";
        dragTargetIndex = -1;
    }

    Component.onCompleted: DorlabTasks.refresh()

    Keys.onEscapePressed: OverlayService.closeCurrentPanel()

    Shortcut {
        sequence: "Ctrl+F"
        enabled: OverlayService.isOpen("tasks")
        onActivated: root.openSearch()
    }

    Connections {
        target: OverlayService

        function onCurrentPanelUpdated() {
            if (!OverlayService.isOpen("tasks")) {
                root.closeSearch();
            }
        }
    }

    component IconAction: Rectangle {
        id: action

        property string icon: ""
        property color accent: Theme.colors.primary
        property bool available: true
        property bool busy: false
        property int buttonSize: 32

        signal clicked

        Layout.preferredWidth: buttonSize
        Layout.preferredHeight: buttonSize
        radius: Theme.rounding.full
        color: actionMouseArea.containsMouse && action.available ? Theme.colors.surfaceVariant : Theme.colors.surface
        border.width: 1
        border.color: actionMouseArea.containsMouse && action.available ? action.accent : Theme.colors.surfaceVariant
        opacity: action.available || action.busy ? 1 : 0.35

        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: !action.busy && action.icon === "󰐊" ? 1 : 0
            text: action.busy ? "󰔟" : action.icon
            color: action.accent
            font: Theme.font.icon
        }

        MouseArea {
            id: actionMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: action.available
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: action.clicked()
        }
    }

    component InlineCreateForm: Rectangle {
        id: form

        property string placeholder: ""
        property string submitLabel: "Crear"
        property bool busy: false

        signal submitted(string value)
        signal cancelled

        Layout.fillWidth: true
        Layout.preferredHeight: 48
        color: Theme.colors.background
        radius: Theme.rounding.normal
        border.width: 1
        border.color: Theme.colors.surfaceVariant

        function focusInput() {
            input.forceActiveFocus();
        }

        function cancelForm() {
            input.text = "";
            form.cancelled();
            root.restorePanelFocus();
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            TextInput {
                id: input
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                text: ""
                color: Theme.colors.text
                selectionColor: Theme.colors.primary
                selectedTextColor: Theme.colors.background
                font: Theme.font.overlay
                clip: true
                leftPadding: 8

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: input.leftPadding
                    verticalAlignment: Text.AlignVCenter
                    text: form.placeholder
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                    visible: input.text.length === 0
                }

                Keys.onReturnPressed: {
                    if (input.text.trim().length > 0 && !DorlabTasks.mutationInProgress) {
                        form.submitted(input.text);
                        input.text = "";
                    }
                }
                Keys.onEscapePressed: event => {
                    form.cancelForm();
                    event.accepted = true;
                }
            }

            IconAction {
                icon: ""
                busy: form.busy
                available: input.text.trim().length > 0 && !DorlabTasks.mutationInProgress
                onClicked: {
                    form.submitted(input.text);
                    input.text = "";
                }
            }

            IconAction {
                icon: ""
                accent: Theme.colors.overlay
                available: !DorlabTasks.mutationInProgress
                onClicked: form.cancelForm()
            }
        }
    }

    component SearchBox: Rectangle {
        function focusInput() {
            searchInput.forceActiveFocus();
            searchInput.selectAll();
        }

        function releaseFocus() {
            searchInput.focus = false;
        }

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        color: Theme.colors.background
        radius: Theme.rounding.normal
        border.width: 1
        border.color: searchInput.activeFocus ? Theme.colors.primary : Theme.colors.surfaceVariant

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: ""
                color: Theme.colors.overlay
                font: Theme.font.icon
            }

            TextInput {
                id: searchInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                text: root.searchText
                color: Theme.colors.text
                selectionColor: Theme.colors.primary
                selectedTextColor: Theme.colors.background
                font: Theme.font.overlay
                clip: true
                onTextChanged: root.searchText = text
                Keys.onEscapePressed: event => {
                    root.closeSearch();
                    event.accepted = true;
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Buscar tareas..."
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                    visible: searchInput.text.length === 0 && !searchInput.activeFocus
                }
            }
        }
    }

    component FocusCard: Rectangle {
        id: focusCard

        Layout.fillWidth: true
        Layout.preferredHeight: DorlabTasks.hasTrackedTask ? 118 : 0
        visible: DorlabTasks.hasTrackedTask
        color: Theme.colors.surface
        radius: Theme.rounding.normal
        border.width: 1
        border.color: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.warning
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: Theme.rounding.full
                    color: Theme.colors.surfaceVariant
                    border.width: 1
                    border.color: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.warning

                    Text {
                        anchors.centerIn: parent
                        text: DorlabTasks.hasActiveTask ? "󰐊" : "󰏤"
                        color: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.warning
                        font: Theme.font.base
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: DorlabTasks.trackedTaskTitle
                        color: Theme.colors.text
                        font: Theme.font.base
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: DorlabTasks.hasActiveTask ? DorlabTasks.activeTask?.team_id ? DorlabTasks.findTeam(DorlabTasks.activeTask.team_id)?.name ?? "" : "" : DorlabTasks.lastTrackedTask?.team_name ?? ""
                        color: Theme.colors.overlay
                        font: Theme.font.overlay
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: DorlabTasks.hasActiveTask ? DorlabTasks.formatDuration(DorlabTasks.activeElapsedSeconds) : "Pausada"
                    color: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.warning
                    font: Theme.font.title
                }

                IconAction {
                    icon: DorlabTasks.hasActiveTask ? "󰏤" : "󰐊"
                    accent: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.warning
                    busy: DorlabTasks.actionInProgress
                    available: !DorlabTasks.mutationInProgress
                    onClicked: {
                        if (DorlabTasks.hasActiveTask) {
                            DorlabTasks.pauseActiveTask();
                        } else {
                            DorlabTasks.resumeLastTrackedTask();
                        }
                    }
                }

                IconAction {
                    icon: ""
                    accent: Theme.colors.error
                    busy: DorlabTasks.actionInProgress
                    available: !DorlabTasks.mutationInProgress
                    onClicked: DorlabTasks.stopTracking(DorlabTasks.trackedTaskId, DorlabTasks.trackedTeamId)
                }
            }
        }
    }

    component TaskRow: Rectangle {
        id: taskRow

        required property var task

        property bool editingTitle: false

        readonly property bool isActive: DorlabTasks.sameId(DorlabTasks.activeTeamId, task.team_id) && DorlabTasks.sameId(DorlabTasks.activeTaskId, task.id)
        readonly property bool isPaused: DorlabTasks.trackedTaskPaused && DorlabTasks.sameId(DorlabTasks.lastTrackedTeamId, task.team_id) && DorlabTasks.sameId(DorlabTasks.lastTrackedTaskId, task.id)
        readonly property bool isBusy: DorlabTasks.actionInProgress && DorlabTasks.sameId(DorlabTasks.actionTeamId, task.team_id) && DorlabTasks.sameId(DorlabTasks.actionTaskId, task.id)
        readonly property bool isDeleting: DorlabTasks.sameId(DorlabTasks.deletingTeamId, task.team_id) && DorlabTasks.sameId(DorlabTasks.deletingTaskId, task.id)
        readonly property bool isUpdating: DorlabTasks.sameId(DorlabTasks.updatingTeamId, task.team_id) && DorlabTasks.sameId(DorlabTasks.updatingTaskId, task.id)
        readonly property bool playDisabled: DorlabTasks.hasActiveTask && !isActive || task.completed
        readonly property int durationVersion: DorlabTasks.durationVersion
        readonly property int activeElapsed: DorlabTasks.activeElapsedSeconds

        Layout.fillWidth: true
        height: 58
        radius: Theme.rounding.normal
        color: rowMouseArea.containsMouse || isActive || isPaused ? Theme.colors.surfaceVariant : Theme.colors.background
        border.width: 1
        border.color: isActive ? Theme.colors.primary : isPaused ? Theme.colors.warning : Theme.colors.surfaceVariant
        opacity: task.completed ? 0.62 : 1

        MouseArea {
            id: rowMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: Theme.rounding.small
                color: task.completed ? Theme.colors.primary : "transparent"
                border.width: 1
                border.color: task.completed ? Theme.colors.primary : Theme.colors.overlay
                opacity: taskRow.isActive ? 0.4 : 1

                Text {
                    anchors.centerIn: parent
                    text: task.completed ? "" : ""
                    color: Theme.colors.background
                    font: Theme.font.icon
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !DorlabTasks.mutationInProgress && !taskRow.isActive
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: DorlabTasks.toggleTaskCompleted(taskRow.task)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    visible: !taskRow.editingTitle
                    text: DorlabTasks.taskTitle(taskRow.task)
                    color: Theme.colors.text
                    font.family: Theme.font.overlay.family
                    font.pixelSize: Theme.font.overlay.pixelSize
                    font.weight: Theme.font.overlay.weight
                    elide: Text.ElideRight

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onDoubleClicked: {
                            if (!DorlabTasks.mutationInProgress) {
                                taskRow.editingTitle = true;
                                Qt.callLater(() => titleInput.forceActiveFocus());
                            }
                        }
                    }
                }

                TextInput {
                    id: titleInput
                    Layout.fillWidth: true
                    visible: taskRow.editingTitle
                    text: DorlabTasks.taskTitle(taskRow.task)
                    color: Theme.colors.text
                    selectionColor: Theme.colors.primary
                    selectedTextColor: Theme.colors.background
                    font: Theme.font.overlay
                    clip: true
                    onAccepted: {
                        DorlabTasks.renameTask(taskRow.task, text);
                        taskRow.editingTitle = false;
                        root.restorePanelFocus();
                    }
                    Keys.onEscapePressed: event => {
                        taskRow.editingTitle = false;
                        root.restorePanelFocus();
                        event.accepted = true;
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        taskRow.durationVersion;
                        taskRow.activeElapsed;
                        return `Total ${DorlabTasks.taskEntriesLabel(taskRow.task)} · ${DorlabTasks.taskLastEntryLabel(taskRow.task)}`;
                    }
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                }
            }

            Text {
                visible: taskRow.isActive || taskRow.isPaused
                text: taskRow.isActive ? "Activa" : "Pausada"
                color: taskRow.isActive ? Theme.colors.primary : Theme.colors.warning
                font: Theme.font.overlay
            }

            IconAction {
                buttonSize: 28
                icon: taskRow.isActive ? "󰏤" : "󰐊"
                accent: taskRow.isPaused ? Theme.colors.warning : Theme.colors.primary
                busy: taskRow.isBusy
                available: !DorlabTasks.mutationInProgress && !taskRow.playDisabled
                onClicked: {
                    if (taskRow.isActive) {
                        DorlabTasks.pauseTask(taskRow.task);
                    } else {
                        DorlabTasks.startTask(taskRow.task);
                    }
                }
            }

            IconAction {
                buttonSize: taskRow.isActive || taskRow.isPaused ? 28 : 0
                visible: taskRow.isActive || taskRow.isPaused
                icon: ""
                accent: Theme.colors.error
                busy: taskRow.isBusy
                available: !DorlabTasks.mutationInProgress
                onClicked: DorlabTasks.stopTracking(taskRow.task)
            }

            IconAction {
                buttonSize: 28
                icon: ""
                accent: Theme.colors.error
                busy: taskRow.isDeleting
                available: !DorlabTasks.mutationInProgress && !taskRow.isActive
                onClicked: DorlabTasks.deleteTask(taskRow.task)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: DorlabTasks.workspaceName
                    color: Theme.colors.text
                    font: Theme.font.title
                }

                Text {
                    text: `${DorlabTasks.teams.length} equipos · ${DorlabTasks.tasks.length} tareas`
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                }
            }

            IconAction {
                visible: root.hiddenTeams.length > 0
                icon: ""
                accent: root.showHiddenTeams ? Theme.colors.primary : Theme.colors.text
                onClicked: root.showHiddenTeams = !root.showHiddenTeams
            }

            IconAction {
                icon: ""
                accent: root.showCreateTeamForm ? Theme.colors.primary : Theme.colors.text
                busy: DorlabTasks.creatingTeam
                available: !DorlabTasks.mutationInProgress
                onClicked: {
                    root.showCreateTeamForm = !root.showCreateTeamForm;
                    root.activeCreateTaskTeamId = -1;
                    if (root.showCreateTeamForm) {
                        Qt.callLater(() => createTeamForm.focusInput());
                    }
                }
            }

            IconAction {
                icon: "󰑐"
                accent: Theme.colors.text
                busy: DorlabTasks.loading
                available: !DorlabTasks.loading
                onClicked: DorlabTasks.refresh()
            }
        }

        SearchBox {
            id: searchBox

            visible: root.showSearch
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: hiddenTeamsContent.implicitHeight + 20
            visible: root.showHiddenTeams && root.hiddenTeams.length > 0
            color: Theme.colors.surface
            radius: Theme.rounding.normal
            border.width: 1
            border.color: Theme.colors.surfaceVariant

            ColumnLayout {
                id: hiddenTeamsContent

                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: `Equipos ocultos (${root.hiddenTeams.length})`
                        color: Theme.colors.text
                        font: Theme.font.base
                    }

                    IconAction {
                        buttonSize: 28
                        icon: ""
                        accent: Theme.colors.overlay
                        onClicked: root.showHiddenTeams = false
                    }
                }

                Repeater {
                    model: root.hiddenTeams

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        color: Theme.colors.background
                        radius: Theme.rounding.normal

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: DorlabTasks.teamName(modelData)
                                color: Theme.colors.text
                                font: Theme.font.overlay
                                elide: Text.ElideRight
                            }

                            IconAction {
                                buttonSize: 28
                                icon: ""
                                onClicked: DorlabTasks.setTeamHidden(modelData.id, false)
                            }
                        }
                    }
                }
            }
        }

        InlineCreateForm {
            id: createTeamForm
            visible: root.showCreateTeamForm
            placeholder: "Introduce el nombre del equipo..."
            busy: DorlabTasks.creatingTeam
            onSubmitted: value => {
                DorlabTasks.createTeam(value);
                root.showCreateTeamForm = false;
            }
            onCancelled: root.showCreateTeamForm = false
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: errorText.implicitHeight + 18
            visible: DorlabTasks.error.length > 0
            color: Theme.colors.surface
            radius: Theme.rounding.normal
            border.width: 1
            border.color: Theme.colors.error

            Text {
                id: errorText
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: DorlabTasks.error
                color: Theme.colors.error
                font: Theme.font.overlay
                elide: Text.ElideRight
            }
        }

        Flickable {
            id: teamsFlickable

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: contentColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: 10

                FocusCard {}

                Text {
                    Layout.fillWidth: true
                    visible: !DorlabTasks.loading && DorlabTasks.teams.length === 0
                    text: "No hay equipos"
                    color: Theme.colors.overlay
                    font: Theme.font.base
                    horizontalAlignment: Text.AlignHCenter
                }

                Repeater {
                    id: teamRepeater

                    model: {
                        DorlabTasks.layoutVersion;
                        DorlabTasks.teams;
                        return DorlabTasks.orderedTeams(false);
                    }

                    delegate: Item {
                        id: teamSlot

                        required property int index
                        required property var modelData
                        property real cardOffset: teamCard.y
                        property var pendingTasks: {
                            DorlabTasks.durationVersion;
                            root.searchText;
                            return DorlabTasks.pendingTasksForTeam(modelData.id, root.searchText);
                        }
                        property var completedTasks: {
                            DorlabTasks.durationVersion;
                            root.searchText;
                            return DorlabTasks.completedTasksForTeam(modelData.id, root.searchText);
                        }
                        readonly property bool deleting: DorlabTasks.isDeletingTeam(modelData.id)
                        readonly property bool hasActiveTask: DorlabTasks.sameId(DorlabTasks.activeTeamId, modelData.id)
                        readonly property bool searchActive: DorlabTasks.normalizeSearchText(root.searchText).length > 0
                        readonly property bool hasSearchMatches: pendingTasks.length > 0 || completedTasks.length > 0
                        readonly property bool storedCollapsed: {
                            DorlabTasks.layoutVersion;
                            return DorlabTasks.isTeamCollapsed(modelData.id);
                        }
                        readonly property bool creatingTask: DorlabTasks.sameId(root.activeCreateTaskTeamId, modelData.id)
                        readonly property bool collapsed: storedCollapsed && !(searchActive && hasSearchMatches) && !creatingTask

                        function resetCardPosition() {
                            teamCard.y = 0;
                        }

                        function focusCreateInput() {
                            taskCreateForm.focusInput();
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: teamContent.implicitHeight + 22
                        z: dragArea.drag.active ? 100 : 0

                        Rectangle {
                            id: teamCard

                            width: parent.width
                            height: parent.height
                            y: 0
                            radius: Theme.rounding.normal
                            color: Theme.colors.surface
                            border.width: root.dragTargetIndex === teamSlot.index && root.draggedTeamId.length > 0 ? 2 : 1
                            border.color: root.dragTargetIndex === teamSlot.index && root.draggedTeamId.length > 0 ? Theme.colors.primary : Theme.colors.surfaceVariant
                            opacity: dragArea.drag.active ? 0.92 : 1

                            onYChanged: {
                                if (dragArea.drag.active) {
                                    root.updateDragTarget(teamSlot);
                                }
                            }

                            ColumnLayout {
                                id: teamContent
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Item {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 32

                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            color: dragArea.containsMouse || dragArea.drag.active ? Theme.colors.primary : Theme.colors.overlay
                                            font: Theme.font.icon
                                        }

                                        MouseArea {
                                            id: dragArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            preventStealing: true
                                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            drag.target: teamCard
                                            drag.axis: Drag.YAxis
                                            onPressed: {
                                                root.draggedTeamId = String(teamSlot.modelData.id);
                                                root.dragTargetIndex = teamSlot.index;
                                                teamsFlickable.interactive = false;
                                            }
                                            onReleased: root.finishTeamDrag(teamSlot)
                                            onCanceled: root.cancelTeamDrag(teamSlot)
                                        }

                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: headerLabels.implicitHeight

                                        ColumnLayout {
                                            id: headerLabels

                                            anchors.fill: parent
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    Layout.minimumWidth: 14
                                                    Layout.preferredWidth: 14
                                                    Layout.maximumWidth: 14
                                                    text: teamSlot.collapsed ? "" : ""
                                                    color: Theme.colors.overlay
                                                    font.family: Theme.font.icon.family
                                                    font.pixelSize: 10
                                                    horizontalAlignment: Text.AlignHCenter
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: DorlabTasks.teamName(teamSlot.modelData)
                                                    color: Theme.colors.text
                                                    font: Theme.font.base
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                text: `${teamSlot.pendingTasks.length} pendientes · ${teamSlot.completedTasks.length} completadas`
                                                color: Theme.colors.overlay
                                                font: Theme.font.overlay
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: DorlabTasks.toggleTeamCollapsed(teamSlot.modelData.id)
                                        }
                                    }

                                    IconAction {
                                        buttonSize: 28
                                        icon: ""
                                        accent: Theme.colors.overlay
                                        available: !teamSlot.hasActiveTask
                                        onClicked: {
                                            root.activeCreateTaskTeamId = -1;
                                            DorlabTasks.setTeamHidden(teamSlot.modelData.id, true);
                                        }
                                    }

                                    IconAction {
                                        buttonSize: 28
                                        icon: ""
                                        accent: teamSlot.creatingTask ? Theme.colors.primary : Theme.colors.text
                                        busy: DorlabTasks.creatingTask && DorlabTasks.sameId(DorlabTasks.creatingTeamId, teamSlot.modelData.id)
                                        available: !DorlabTasks.mutationInProgress
                                        onClicked: {
                                            root.showCreateTeamForm = false;
                                            root.activeCreateTaskTeamId = teamSlot.creatingTask ? -1 : teamSlot.modelData.id;
                                            if (root.activeCreateTaskTeamId !== -1) {
                                                DorlabTasks.setTeamCollapsed(teamSlot.modelData.id, false);
                                                const teamId = teamSlot.modelData.id;
                                                Qt.callLater(() => root.focusTaskCreateInput(teamId));
                                            }
                                        }
                                    }

                                    IconAction {
                                        buttonSize: 28
                                        icon: ""
                                        accent: Theme.colors.error
                                        busy: teamSlot.deleting
                                        available: !DorlabTasks.mutationInProgress && !teamSlot.hasActiveTask
                                        onClicked: DorlabTasks.deleteTeam(teamSlot.modelData.id)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    visible: !teamSlot.collapsed
                                    spacing: 8

                                    InlineCreateForm {
                                        id: taskCreateForm

                                        visible: teamSlot.creatingTask
                                        placeholder: `Introduce el nombre de la tarea para ${DorlabTasks.teamName(teamSlot.modelData)}...`
                                        busy: DorlabTasks.creatingTask && DorlabTasks.sameId(DorlabTasks.creatingTeamId, teamSlot.modelData.id)
                                        onSubmitted: value => {
                                            DorlabTasks.createTask(teamSlot.modelData.id, value);
                                            root.activeCreateTaskTeamId = -1;
                                        }
                                        onCancelled: root.activeCreateTaskTeamId = -1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: teamSlot.pendingTasks.length === 0 && teamSlot.completedTasks.length === 0
                                        text: teamSlot.searchActive ? "Sin coincidencias" : "Sin tareas"
                                        color: Theme.colors.overlay
                                        font: Theme.font.overlay
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: teamSlot.pendingTasks.length > 0
                                        text: "Pendientes"
                                        color: Theme.colors.primary
                                        font: Theme.font.overlay
                                    }

                                    Repeater {
                                        model: teamSlot.pendingTasks

                                        delegate: TaskRow {
                                            required property var modelData

                                            task: modelData
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: teamSlot.completedTasks.length > 0
                                        text: "Completadas"
                                        color: Theme.colors.success
                                        font: Theme.font.overlay
                                    }

                                    Repeater {
                                        model: teamSlot.completedTasks

                                        delegate: TaskRow {
                                            required property var modelData

                                            task: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
