import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

Item {
    id: root

    property string searchText: ""
    property bool showCreateTeamForm: false
    property int activeCreateTaskTeamId: -1

    Component.onCompleted: DorlabTasks.refresh()

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
        color: actionMouseArea.containsMouse && action.available ? action.accent : Theme.colors.surface
        border.width: 1
        border.color: action.accent
        opacity: action.available || action.busy ? 1 : 0.35

        Text {
            anchors.centerIn: parent
            text: action.busy ? "󰔟" : action.icon
            color: actionMouseArea.containsMouse && action.available ? Theme.colors.background : action.accent
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

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: form.placeholder
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                    visible: input.text.length === 0 && !input.activeFocus
                }

                Keys.onReturnPressed: {
                    if (input.text.trim().length > 0 && !DorlabTasks.mutationInProgress) {
                        form.submitted(input.text);
                        input.text = "";
                    }
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
                onClicked: {
                    input.text = "";
                    form.cancelled();
                }
            }
        }
    }

    component SearchBox: Rectangle {
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
                    }
                    Keys.onEscapePressed: taskRow.editingTitle = false
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

        SearchBox {}

        InlineCreateForm {
            id: createTeamForm
            visible: root.showCreateTeamForm
            placeholder: "Nuevo equipo"
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
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: contentColumn.implicitHeight

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
                    model: DorlabTasks.teams

                    delegate: Rectangle {
                        id: teamCard

                        required property var modelData
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

                        Layout.fillWidth: true
                        Layout.preferredHeight: teamContent.implicitHeight + 22
                        radius: Theme.rounding.normal
                        color: Theme.colors.surface
                        border.width: 1
                        border.color: hasActiveTask ? Theme.colors.primary : Theme.colors.surfaceVariant

                        ColumnLayout {
                            id: teamContent
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: DorlabTasks.teamName(teamCard.modelData)
                                        color: Theme.colors.text
                                        font: Theme.font.base
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: `${teamCard.pendingTasks.length} pendientes · ${teamCard.completedTasks.length} completadas`
                                        color: Theme.colors.overlay
                                        font: Theme.font.overlay
                                    }
                                }

                                IconAction {
                                    icon: ""
                                    accent: DorlabTasks.sameId(root.activeCreateTaskTeamId, teamCard.modelData.id) ? Theme.colors.primary : Theme.colors.text
                                    busy: DorlabTasks.creatingTask && DorlabTasks.sameId(DorlabTasks.creatingTeamId, teamCard.modelData.id)
                                    available: !DorlabTasks.mutationInProgress
                                    onClicked: {
                                        root.showCreateTeamForm = false;
                                        root.activeCreateTaskTeamId = DorlabTasks.sameId(root.activeCreateTaskTeamId, teamCard.modelData.id) ? -1 : teamCard.modelData.id;
                                    }
                                }

                                IconAction {
                                    icon: ""
                                    accent: Theme.colors.error
                                    busy: teamCard.deleting
                                    available: !DorlabTasks.mutationInProgress && !teamCard.hasActiveTask
                                    onClicked: DorlabTasks.deleteTeam(teamCard.modelData.id)
                                }
                            }

                            InlineCreateForm {
                                visible: DorlabTasks.sameId(root.activeCreateTaskTeamId, teamCard.modelData.id)
                                placeholder: `Nueva tarea en ${DorlabTasks.teamName(teamCard.modelData)}`
                                busy: DorlabTasks.creatingTask && DorlabTasks.sameId(DorlabTasks.creatingTeamId, teamCard.modelData.id)
                                onSubmitted: value => {
                                    DorlabTasks.createTask(teamCard.modelData.id, value);
                                    root.activeCreateTaskTeamId = -1;
                                }
                                onCancelled: root.activeCreateTaskTeamId = -1
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: teamCard.pendingTasks.length === 0 && teamCard.completedTasks.length === 0
                                text: "Sin tareas"
                                color: Theme.colors.overlay
                                font: Theme.font.overlay
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: teamCard.pendingTasks.length > 0
                                text: "Pendientes"
                                color: Theme.colors.primary
                                font: Theme.font.overlay
                            }

                            Repeater {
                                model: teamCard.pendingTasks

                                delegate: TaskRow {
                                    required property var modelData

                                    task: modelData
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: teamCard.completedTasks.length > 0
                                text: "Completadas"
                                color: Theme.colors.success
                                font: Theme.font.overlay
                            }

                            Repeater {
                                model: teamCard.completedTasks

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
