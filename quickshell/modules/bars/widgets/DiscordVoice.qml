import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import qs.common
import qs.services

Rectangle {
    id: root

    property var voiceState: ({
        connected: false,
        authenticated: false,
        auth_required: false,
        channel: null,
        mute: false,
        deaf: false,
        self_speaking: false,
        speaking: [],
        participants: [],
        error: ""
    })
    property string hint: "Discord desconectado"

    height: parent.height * 0.8
    implicitHeight: parent.height * 0.8
    implicitWidth: controls.implicitWidth + 8
    Layout.alignment: Qt.AlignVCenter
    visible: voiceState.authenticated || (voiceState.connected && voiceState.auth_required)
    radius: Theme.rounding.normal
    color: "transparent"
    readonly property string voiceLabel: {
        if (!voiceState.authenticated) return voiceState.error || "Sin autorizar";
        if (!voiceState.channel) return "No estás en un canal de voz";
        return voiceState.channel.name || "Canal de voz";
    }

    function invoke(action) {
        if (commandProc.running) return;
        commandProc.command = [SendaManager.binaryPath, "discord", action];
        commandProc.running = true;
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true;
    }

    function updateVoiceState(next) {
        root.voiceState = next;
        if (next.error) root.hint = next.error;
        else if (!next.connected) root.hint = "Abre Discord y pulsa para conectar";
        else if (next.auth_required) root.hint = "Pulsa para autorizar el acceso de voz";
        else if (!next.authenticated) root.hint = "Conectando con Discord…";
        else if (!next.channel) root.hint = "No estás en un canal de voz";
        else root.hint = `Conectado a ${next.channel.name || "un canal de voz"}`;
    }

    Component.onCompleted: {
        root.refresh();
        watchSocket.connected = true;
        root.invoke("connect");
    }

    Timer {
        id: watchRetryTimer
        interval: 1000
        repeat: true
        running: watchConnectedOnce && !watchSocket.connected
        onTriggered: watchSocket.connected = true
    }

    property bool watchConnectedOnce: false

    Socket {
        id: watchSocket
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/senda-discord.sock`
        connected: false

        onConnectedChanged: {
            if (!connected) return;
            root.watchConnectedOnce = true;
            write('{"action":"watch"}\n');
            flush();
        }

        parser: SplitParser {
            onRead: line => {
                try {
                    const message = JSON.parse(line);
                    root.updateVoiceState(message.state || message);
                } catch (e) {
                    root.hint = "No se pudo leer el estado de Discord";
                }
            }
        }
    }

    Process {
        id: statusProc
        running: false
        command: [SendaManager.binaryPath, "discord", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    root.updateVoiceState(next);
                } catch (e) {
                    root.hint = "No se pudo leer el estado de Discord";
                }
            }
        }
    }

    Process {
        id: commandProc
        running: false
        command: []
        onExited: {
            root.refresh();
            if (!watchSocket.connected) watchSocket.connected = true;
        }
    }

    RowLayout {
        id: controls
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 5

        Rectangle {
            id: connectionButton
            visible: root.voiceState.connected && root.voiceState.auth_required
            Layout.preferredWidth: 34
            Layout.preferredHeight: parent.height
            radius: Theme.rounding.normal
            color: connectionMouse.containsMouse ? Theme.colors.surfaceVariant : Theme.colors.surface

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰙯"
                color: Theme.colors.primary
                font: Theme.font.base
            }

            MouseArea {
                id: connectionMouse
                anchors.fill: parent
                enabled: !commandProc.running
                acceptedButtons: Qt.LeftButton
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.invoke(root.voiceState.auth_required || root.voiceState.connected ? "authorize" : "connect")
            }

        }

        Rectangle {
            id: voiceControlsGroup
            visible: root.voiceState.authenticated
            Layout.preferredWidth: voiceControlsRow.implicitWidth + 12
            Layout.preferredHeight: parent.height
            radius: Theme.rounding.normal
            color: Theme.colors.surface

            RowLayout {
                id: voiceControlsRow
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 0

                Row {
                    id: participantAvatars
                    readonly property int avatarCount: Math.min((root.voiceState.participants || []).length, 6)
                    visible: avatarCount > 0
                    Layout.preferredWidth: avatarCount > 0 ? avatarCount * 30 + (avatarCount - 1) * spacing : 0
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -7

                    Repeater {
                        model: (root.voiceState.participants || []).slice(0, 6)

                        delegate: Item {
                            id: participantAvatar
                            required property var modelData
                            required property int index
                            readonly property bool isSpeaking: (root.voiceState.speaking || []).indexOf(modelData.id) !== -1
                            width: 30
                            height: 30
                            z: index

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: participantAvatar.isSpeaking ? Theme.colors.success : Theme.colors.surfaceVariant
                                clip: true

                                Image {
                                    id: avatarImage
                                    anchors.fill: parent
                                    anchors.margins: participantAvatar.isSpeaking ? 2 : 1
                                    source: participantAvatar.modelData.avatar || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: false
                                }
                                OpacityMask {
                                    anchors.fill: avatarImage
                                    source: avatarImage
                                    maskSource: Rectangle {
                                        width: avatarImage.width
                                        height: avatarImage.height
                                        radius: width / 2
                                        color: "white"
                                    }
                                    visible: avatarImage.status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: (participantAvatar.modelData.name || "?").slice(0, 1).toUpperCase()
                                    color: Theme.colors.text
                                    font.family: Theme.font.overlay.family
                                    font.pixelSize: 11
                                    visible: avatarImage.status !== Image.Ready
                                }
                            }

                        }
                    }
                }

                Rectangle {
                    id: microphoneButton
                    enabled: !commandProc.running
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: parent.height
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: root.voiceState.mute ? "󰍭" : "󰍬"
                        color: root.voiceState.mute ? Theme.colors.error : Theme.colors.success
                        font: Theme.font.base
                    }

                    MouseArea {
                        id: microphoneMouse
                        anchors.fill: parent
                        enabled: microphoneButton.enabled
                        acceptedButtons: Qt.LeftButton
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.invoke(root.voiceState.mute ? "unmute" : "mute")
                    }

                }

                Rectangle {
                    id: audioButton
                    enabled: !commandProc.running
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: parent.height
                    color: "transparent"

                    Text {
                        id: headphoneIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "󰋋"
                        color: root.voiceState.deaf ? Theme.colors.error : Theme.colors.primary
                        font: Theme.font.base
                    }
                    Rectangle {
                        visible: root.voiceState.deaf
                        width: 22
                        height: 2
                        radius: 1
                        color: Theme.colors.error
                        rotation: -45
                        anchors.centerIn: headphoneIcon
                    }

                    MouseArea {
                        id: audioMouse
                        anchors.fill: parent
                        enabled: audioButton.enabled
                        acceptedButtons: Qt.LeftButton
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.invoke(root.voiceState.deaf ? "undeafen" : "deafen")
                    }

                }

                Rectangle {
                    id: leaveButton
                    visible: !!root.voiceState.channel
                    enabled: visible && !commandProc.running
                    Layout.preferredWidth: visible ? 32 : 0
                    Layout.preferredHeight: parent.height
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "󰏵"
                        color: Theme.colors.error
                        font: Theme.font.base
                    }

                    MouseArea {
                        id: leaveMouse
                        anchors.fill: parent
                        enabled: leaveButton.enabled
                        acceptedButtons: Qt.LeftButton
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.invoke("leave")
                    }
                }
            }
        }
    }
}
