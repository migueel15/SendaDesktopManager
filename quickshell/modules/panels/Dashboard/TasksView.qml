import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

Item {
    id: root

    property bool showCreateForm: false

    Component.onCompleted: DorlabTasks.refresh()

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
                    text: "Tasks"
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

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Theme.rounding.full
                color: addMouseArea.containsMouse || root.showCreateForm ? Theme.colors.surfaceVariant : Theme.colors.surface
                border.width: 1
                border.color: root.showCreateForm ? Theme.colors.primary : Theme.colors.surfaceVariant
                opacity: DorlabTasks.mutationInProgress ? 0.5 : 1

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: root.showCreateForm ? Theme.colors.primary : Theme.colors.text
                    font: Theme.font.base
                }

                MouseArea {
                    id: addMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !DorlabTasks.mutationInProgress
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.showCreateForm = !root.showCreateForm;
                        if (root.showCreateForm) {
                            Qt.callLater(() => newTaskTitle.forceActiveFocus());
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Theme.rounding.full
                color: refreshMouseArea.containsMouse ? Theme.colors.surfaceVariant : Theme.colors.surface
                border.width: 1
                border.color: Theme.colors.surfaceVariant
                opacity: DorlabTasks.loading ? 0.5 : 1

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    color: Theme.colors.text
                    font: Theme.font.base
                }

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !DorlabTasks.loading
                    onClicked: DorlabTasks.refresh()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            visible: root.showCreateForm
            color: Theme.colors.surface
            radius: Theme.rounding.normal
            border.width: 1
            border.color: Theme.colors.surfaceVariant

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
                    border.color: newTaskTitle.activeFocus ? Theme.colors.primary : Theme.colors.surfaceVariant

                    TextInput {
                        id: newTaskTitle
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
                            text: "Nueva tarea"
                            color: Theme.colors.overlay
                            font: Theme.font.overlay
                            visible: newTaskTitle.text.length === 0 && !newTaskTitle.activeFocus
                        }

                        Keys.onReturnPressed: {
                            if (createMouseArea.enabled) {
                                DorlabTasks.createTask(newTaskTitle.text);
                                newTaskTitle.text = "";
                                root.showCreateForm = false;
                            }
                        }
                    }
                }

                Rectangle {
                    id: createButton

                    readonly property bool canCreate: newTaskTitle.text.trim().length > 0 && !DorlabTasks.mutationInProgress

                    Layout.preferredWidth: createText.implicitWidth + 24
                    Layout.fillHeight: true
                    radius: Theme.rounding.small
                    color: createMouseArea.containsMouse && createMouseArea.enabled ? Theme.colors.primary : Theme.colors.surfaceVariant
                    opacity: canCreate ? 1 : 0.45

                    Text {
                        id: createText
                        anchors.centerIn: parent
                        text: DorlabTasks.creatingTask ? "Creando" : "Crear"
                        color: createMouseArea.containsMouse && createMouseArea.enabled ? Theme.colors.background : Theme.colors.text
                        font: Theme.font.overlay
                    }

                    MouseArea {
                        id: createMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: createButton.canCreate
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            DorlabTasks.createTask(newTaskTitle.text);
                            newTaskTitle.text = "";
                            root.showCreateForm = false;
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
                            newTaskTitle.text = "";
                            root.showCreateForm = false;
                        }
                    }
                }
            }
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
            visible: !DorlabTasks.loading && DorlabTasks.error.length === 0 && DorlabTasks.tasks.length === 0
            text: "No hay tareas"
            color: Theme.colors.overlay
            font: Theme.font.base
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        ListView {
            id: tasksList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: DorlabTasks.tasks.length > 0
            clip: true
            spacing: 8
            model: DorlabTasks.tasks

            delegate: Rectangle {
                id: taskRow

                required property var modelData

                readonly property bool isActive: DorlabTasks.activeTaskId === modelData.id
                readonly property bool isPaused: DorlabTasks.trackedTaskPaused && DorlabTasks.lastTrackedTaskId === modelData.id
                readonly property bool isBusy: DorlabTasks.actionInProgress && DorlabTasks.actionTaskId === modelData.id
                readonly property bool isDeleting: DorlabTasks.deletingTaskId === modelData.id
                readonly property bool playDisabled: DorlabTasks.hasActiveTask && !isActive
                readonly property int durationVersion: DorlabTasks.durationVersion
                readonly property int activeElapsed: DorlabTasks.activeElapsedSeconds

                width: tasksList.width
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: taskRow.modelData.title
                                color: Theme.colors.text
                                font: Theme.font.base
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                taskRow.durationVersion;
                                taskRow.activeElapsed;
                                return `Total ${DorlabTasks.formatDuration(DorlabTasks.taskTotalSeconds(taskRow.modelData.id))}`;
                            }
                            color: Theme.colors.overlay
                            font: Theme.font.overlay
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: taskRow.isActive || taskRow.isPaused ? activeLabel.implicitWidth + 14 : 0
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
                        visible: taskRow.isActive || taskRow.isPaused
                        radius: Theme.rounding.full
                        color: taskRow.isActive ? Theme.colors.primary : Theme.colors.warning

                        Text {
                            id: activeLabel
                            anchors.centerIn: parent
                            text: taskRow.isActive ? "Activa" : "Pausada"
                            color: Theme.colors.background
                            font: Theme.font.overlay
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: Theme.rounding.full
                        color: actionMouseArea.containsMouse && actionMouseArea.enabled ? Theme.colors.primary : Theme.colors.surface
                        border.width: 1
                        border.color: taskRow.isActive ? Theme.colors.primary : taskRow.isPaused ? Theme.colors.warning : Theme.colors.surfaceVariant
                        opacity: taskRow.isBusy || actionMouseArea.enabled ? 1 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: taskRow.isBusy ? "󰔟" : taskRow.isActive ? "󰏤" : "󰐊"
                            color: actionMouseArea.containsMouse && actionMouseArea.enabled ? Theme.colors.background : Theme.colors.text
                            font: Theme.font.base
                        }

                        MouseArea {
                            id: actionMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !DorlabTasks.mutationInProgress && !taskRow.playDisabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (taskRow.isActive) {
                                    DorlabTasks.pauseTask(taskRow.modelData.id);
                                } else {
                                    DorlabTasks.startTask(taskRow.modelData.id);
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: taskRow.isActive || taskRow.isPaused ? 38 : 0
                        Layout.preferredHeight: 38
                        visible: taskRow.isActive || taskRow.isPaused
                        radius: Theme.rounding.full
                        color: stopMouseArea.containsMouse && stopMouseArea.enabled ? Theme.colors.error : Theme.colors.surface
                        border.width: 1
                        border.color: Theme.colors.error
                        opacity: taskRow.isBusy || stopMouseArea.enabled ? 1 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: taskRow.isBusy ? "󰔟" : ""
                            color: stopMouseArea.containsMouse && stopMouseArea.enabled ? Theme.colors.background : Theme.colors.error
                            font: Theme.font.base
                        }

                        MouseArea {
                            id: stopMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !DorlabTasks.mutationInProgress
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: DorlabTasks.stopTracking(taskRow.modelData.id)
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: Theme.rounding.full
                        color: deleteMouseArea.containsMouse && deleteMouseArea.enabled ? Theme.colors.error : Theme.colors.surface
                        border.width: 1
                        border.color: taskRow.isDeleting ? Theme.colors.error : Theme.colors.surfaceVariant
                        opacity: taskRow.isDeleting || deleteMouseArea.enabled ? 1 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: taskRow.isDeleting ? "󰔟" : ""
                            color: deleteMouseArea.containsMouse && deleteMouseArea.enabled ? Theme.colors.background : Theme.colors.error
                            font: Theme.font.base
                        }

                        MouseArea {
                            id: deleteMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !DorlabTasks.mutationInProgress && !taskRow.isActive
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: DorlabTasks.deleteTask(taskRow.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
