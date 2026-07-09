import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

Item {
    id: root

    property bool showCreateTeamForm: false
    property int activeCreateTaskTeamId: -1

    Component.onCompleted: DorlabTasks.refresh()

    component IconCircleButton: Rectangle {
        id: button

        property string icon: ""
        property color accent: Theme.colors.primary
        property bool available: true
        property bool busy: false

        signal clicked

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: Theme.rounding.full
        color: buttonMouseArea.containsMouse && button.available ? button.accent : Theme.colors.surface
        border.width: 1
        border.color: button.accent
        opacity: button.available || button.busy ? 1 : 0.35

        Text {
            anchors.centerIn: parent
            text: button.busy ? "󰔟" : button.icon
            color: buttonMouseArea.containsMouse && button.available ? Theme.colors.background : button.accent
            font: Theme.font.base
        }

        MouseArea {
            id: buttonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.available
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
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
        Layout.preferredHeight: 50
        color: Theme.colors.surface
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

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.rounding.small
                color: Theme.colors.background
                border.width: 1
                border.color: input.activeFocus ? Theme.colors.primary : Theme.colors.surfaceVariant

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 10
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
                        if (submitMouseArea.enabled) {
                            form.submitted(input.text);
                            input.text = "";
                        }
                    }
                }
            }

            Rectangle {
                id: submitButton

                readonly property bool canSubmit: input.text.trim().length > 0 && !DorlabTasks.mutationInProgress

                Layout.preferredWidth: submitText.implicitWidth + 24
                Layout.fillHeight: true
                radius: Theme.rounding.small
                color: submitMouseArea.containsMouse && submitMouseArea.enabled ? Theme.colors.primary : Theme.colors.surfaceVariant
                opacity: canSubmit ? 1 : 0.45

                Text {
                    id: submitText
                    anchors.centerIn: parent
                    text: form.busy ? "Creando" : form.submitLabel
                    color: submitMouseArea.containsMouse && submitMouseArea.enabled ? Theme.colors.background : Theme.colors.text
                    font: Theme.font.overlay
                }

                MouseArea {
                    id: submitMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: submitButton.canSubmit
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        form.submitted(input.text);
                        input.text = "";
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: cancelText.implicitWidth + 24
                Layout.fillHeight: true
                radius: Theme.rounding.small
                color: cancelMouseArea.containsMouse ? Theme.colors.surfaceVariant : Theme.colors.background
                border.width: 1
                border.color: Theme.colors.surfaceVariant

                Text {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "Cancelar"
                    color: Theme.colors.text
                    font: Theme.font.overlay
                }

                MouseArea {
                    id: cancelMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        input.text = "";
                        form.cancelled();
                    }
                }
            }
        }
    }

    component TaskRow: Rectangle {
        id: taskRow

        required property var task

        readonly property bool isActive: DorlabTasks.activeTeamId === task.team_id && DorlabTasks.activeTaskId === task.id
        readonly property bool isPaused: DorlabTasks.trackedTaskPaused && DorlabTasks.lastTrackedTeamId === task.team_id && DorlabTasks.lastTrackedTaskId === task.id
        readonly property bool isBusy: DorlabTasks.actionInProgress && DorlabTasks.actionTeamId === task.team_id && DorlabTasks.actionTaskId === task.id
        readonly property bool isDeleting: DorlabTasks.deletingTeamId === task.team_id && DorlabTasks.deletingTaskId === task.id
        readonly property bool playDisabled: DorlabTasks.hasActiveTask && !isActive
        readonly property int durationVersion: DorlabTasks.durationVersion
        readonly property int activeElapsed: DorlabTasks.activeElapsedSeconds

        Layout.fillWidth: true
        height: 72
        radius: Theme.rounding.normal
        color: taskMouseArea.containsMouse || isActive || isPaused ? Theme.colors.surfaceVariant : Theme.colors.surface
        border.width: 1
        border.color: isActive ? Theme.colors.primary : isPaused ? Theme.colors.warning : Theme.colors.surfaceVariant

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        MouseArea {
            id: taskMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 8
                Layout.fillHeight: true
                radius: Theme.rounding.full
                color: taskRow.isActive ? Theme.colors.primary : taskRow.isPaused ? Theme.colors.warning : Theme.colors.overlay
                opacity: taskRow.isActive || taskRow.isPaused ? 1 : 0.35
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: taskRow.task.title
                    color: Theme.colors.text
                    font: Theme.font.base
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        taskRow.durationVersion;
                        taskRow.activeElapsed;
                        return `Total ${DorlabTasks.formatDuration(DorlabTasks.taskTotalSeconds(taskRow.task.team_id, taskRow.task.id))}`;
                    }
                    color: Theme.colors.overlay
                    font: Theme.font.overlay
                }
            }

            Rectangle {
                Layout.preferredWidth: taskRow.isActive || taskRow.isPaused ? statusLabel.implicitWidth + 14 : 0
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                visible: taskRow.isActive || taskRow.isPaused
                radius: Theme.rounding.full
                color: taskRow.isActive ? Theme.colors.primary : Theme.colors.warning

                Text {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: taskRow.isActive ? "Activa" : "Pausada"
                    color: Theme.colors.background
                    font: Theme.font.overlay
                }
            }

            IconCircleButton {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
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

            IconCircleButton {
                Layout.preferredWidth: taskRow.isActive || taskRow.isPaused ? 38 : 0
                Layout.preferredHeight: 38
                visible: taskRow.isActive || taskRow.isPaused
                icon: ""
                accent: Theme.colors.error
                busy: taskRow.isBusy
                available: !DorlabTasks.mutationInProgress
                onClicked: DorlabTasks.stopTracking(taskRow.task)
            }

            IconCircleButton {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
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
                    text: DorlabTasks.hasActiveTask ? `Activa: ${DorlabTasks.activeTask.title}` : DorlabTasks.hasLastTrackedTask ? `Pausada: ${DorlabTasks.lastTrackedTask.title}` : "Sin tarea activa"
                    color: DorlabTasks.hasActiveTask ? Theme.colors.primary : DorlabTasks.hasLastTrackedTask ? Theme.colors.warning : Theme.colors.overlay
                    font: Theme.font.overlay
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            IconCircleButton {
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

            IconCircleButton {
                icon: "󰑐"
                accent: Theme.colors.text
                busy: DorlabTasks.loading
                available: !DorlabTasks.loading
                onClicked: DorlabTasks.refresh()
            }
        }

        InlineCreateForm {
            id: createTeamForm
            visible: root.showCreateTeamForm
            placeholder: "Nuevo equipo"
            submitLabel: "Crear equipo"
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

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !DorlabTasks.loading && DorlabTasks.error.length === 0 && DorlabTasks.teams.length === 0
            text: "No hay equipos"
            color: Theme.colors.overlay
            font: Theme.font.base
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: DorlabTasks.teams.length > 0
            clip: true
            contentHeight: teamsColumn.implicitHeight

            ColumnLayout {
                id: teamsColumn
                width: parent.width
                spacing: 10

                Repeater {
                    model: DorlabTasks.teams

                    delegate: Rectangle {
                        id: teamCard

                        required property var modelData
                        readonly property var teamTasks: DorlabTasks.tasksForTeam(modelData.id)
                        readonly property bool deleting: DorlabTasks.isDeletingTeam(modelData.id)
                        readonly property bool hasActiveTask: DorlabTasks.activeTeamId === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: teamContent.implicitHeight + 20
                        radius: Theme.rounding.normal
                        color: Theme.colors.surface
                        border.width: 1
                        border.color: hasActiveTask ? Theme.colors.primary : Theme.colors.surfaceVariant

                        ColumnLayout {
                            id: teamContent
                            anchors.fill: parent
                            anchors.margins: 10
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
                                        text: `${teamCard.teamTasks.length} tareas`
                                        color: Theme.colors.overlay
                                        font: Theme.font.overlay
                                    }
                                }

                                IconCircleButton {
                                    icon: ""
                                    accent: root.activeCreateTaskTeamId === teamCard.modelData.id ? Theme.colors.primary : Theme.colors.text
                                    busy: DorlabTasks.creatingTask && DorlabTasks.creatingTeamId === teamCard.modelData.id
                                    available: !DorlabTasks.mutationInProgress
                                    onClicked: {
                                        root.showCreateTeamForm = false;
                                        root.activeCreateTaskTeamId = root.activeCreateTaskTeamId === teamCard.modelData.id ? -1 : teamCard.modelData.id;
                                    }
                                }

                                IconCircleButton {
                                    icon: ""
                                    accent: Theme.colors.error
                                    busy: teamCard.deleting
                                    available: !DorlabTasks.mutationInProgress && !teamCard.hasActiveTask
                                    onClicked: DorlabTasks.deleteTeam(teamCard.modelData.id)
                                }
                            }

                            InlineCreateForm {
                                visible: root.activeCreateTaskTeamId === teamCard.modelData.id
                                placeholder: `Nueva tarea en ${DorlabTasks.teamName(teamCard.modelData)}`
                                submitLabel: "Crear tarea"
                                busy: DorlabTasks.creatingTask && DorlabTasks.creatingTeamId === teamCard.modelData.id
                                onSubmitted: value => {
                                    DorlabTasks.createTask(teamCard.modelData.id, value);
                                    root.activeCreateTaskTeamId = -1;
                                }
                                onCancelled: root.activeCreateTaskTeamId = -1
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                visible: teamCard.teamTasks.length === 0
                                text: "No hay tareas en este equipo"
                                color: Theme.colors.overlay
                                font: Theme.font.overlay
                                verticalAlignment: Text.AlignVCenter
                            }

                            Repeater {
                                model: teamCard.teamTasks

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
