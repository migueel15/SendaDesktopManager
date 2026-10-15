import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import qs.common
import qs.services
import qs.common.components.barextension as BarComponents

Rectangle {
    id: root

    property bool expanded: false
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

    onVoiceStateChanged: {
        if (!voiceState.authenticated || !(voiceState.participants || []).length)
            root.expanded = false;
    }

    function itemXInWindow(item, windowContentItem) {
        let x = 0;
        let current = item;
        while (current && current !== windowContentItem) {
            x += current.x;
            current = current.parent;
        }
        return current === windowContentItem ? x : 0;
    }

    function invoke(action) {
        if (commandProc.running) return;
        commandProc.command = [SendaManager.binaryPath, "discord", action];
        commandProc.running = true;
    }

    function openParticipantProfile(userId) {
        const id = String(userId || "");
        if (!id) return;
        Quickshell.execDetached([
            "gtk-launch",
            "discord",
            `discord://-/users/${encodeURIComponent(id)}`
        ]);
    }

    function openCurrentVoiceChannel() {
        const channel = root.voiceState.channel;
        if (!channel || !channel.id) return;
        const guildPath = channel.guild_id ? encodeURIComponent(String(channel.guild_id)) : "@me";
        const channelPath = encodeURIComponent(String(channel.id));
        Quickshell.execDetached([
            "gtk-launch",
            "discord",
            `discord://-/channels/${guildPath}/${channelPath}`
        ]);
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
            color: "transparent"

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
                hoverEnabled: true
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

                    HoverHandler {
                        id: participantAvatarsHover
                        onHoveredChanged: {
                            if (hovered) root.expanded = true;
                        }
                    }

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

                            MouseArea {
                                anchors.fill: parent
                                preventStealing: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openCurrentVoiceChannel()
                            }

                        }
                    }
                }

                Rectangle {
                    id: microphoneButton
                    enabled: !commandProc.running
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: parent.height
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: (root.voiceState.mute || root.voiceState.deaf) ? "󰍭" : "󰍬"
                        color: (root.voiceState.mute || root.voiceState.deaf) ? Theme.colors.error : Theme.colors.success
                        font: Theme.font.base
                    }

                    MouseArea {
                        id: microphoneMouse
                        anchors.fill: parent
                        enabled: microphoneButton.enabled
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.invoke((root.voiceState.mute || root.voiceState.deaf) ? "unmute" : "mute")
                    }

                }

                Rectangle {
                    id: audioButton
                    enabled: !commandProc.running
                    Layout.preferredWidth: 28
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
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.invoke(root.voiceState.deaf ? "undeafen" : "deafen")
                    }

                }

                Rectangle {
                    id: leaveButton
                    visible: !!root.voiceState.channel
                    enabled: visible && !commandProc.running
                    Layout.preferredWidth: visible ? 28 : 0
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
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.invoke("leave")
                    }
                }
            }
        }
    }

    PopupWindow {
        id: participantsExtension

        anchor.window: root.QsWindow.window
        anchor.rect.x: {
            const window = root.QsWindow.window;
            if (!window) return 0;
            return root.itemXInWindow(participantAvatars, window.contentItem)
                + participantAvatars.width / 2 - participantsExtension.width / 2;
        }
        anchor.rect.y: root.QsWindow.window
            ? root.QsWindow.window.contentItem.height - participantsExtensionContent.collapseLift
            : 0
        anchor.rect.width: 1
        anchor.rect.height: 1

        width: 360
        implicitWidth: 360
        implicitHeight: Math.max(1, participantsExtensionContent.height)
        visible: root.expanded || participantsExtensionContent.height > 0.01
        color: "transparent"

        BarComponents.BarExtension {
            id: participantsExtensionContent
            width: participantsExtension.width
            expanded: root.expanded
            expandedHeight: Math.min(380, Math.max(82, participantCount * 64 + 18))
            conflictGroup: "tray-popups"
            autoHideStartsOnExpand: true
            autoHideDelay: 500
            autoHidePaused: participantAvatarsHover.hovered
            onCloseRequested: root.expanded = false

            readonly property int participantCount: (root.voiceState.participants || []).length

            Flickable {
                id: participantListViewport
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                contentWidth: width
                contentHeight: participantList.implicitHeight
                clip: true

                Column {
                    id: participantList
                    width: participantListViewport.width
                    spacing: 3

                    Repeater {
                        model: root.voiceState.participants || []

                        delegate: Item {
                            id: participantRow
                            required property var modelData
                            required property int index

                            readonly property real rpcVolume: Math.max(0, Math.min(200, Number(modelData.volume ?? 100)))
                            readonly property real currentVolume: rpcVolume <= 100
                                ? 100 * Math.pow(rpcVolume / 100, 1 / 2.8)
                                : rpcVolume
                            readonly property bool isMuted: !!modelData.mute
                            readonly property bool isSelfMuted: !!modelData.self_mute
                            readonly property bool isServerMuted: !!modelData.server_mute
                            readonly property bool isSelfDeaf: !!modelData.self_deaf
                            readonly property bool isServerDeaf: !!modelData.server_deaf
                            readonly property bool isSpeaking: (root.voiceState.speaking || []).indexOf(modelData.id) !== -1
                            readonly property string bridgeError: root.voiceState.error || ""
                            property bool readyForVolumeUpdates: false
                            property real previewVolume: currentVolume

                            function toRpcVolume(sliderVolume) {
                                const clampedVolume = Math.max(0, Math.min(200, sliderVolume));
                                if (clampedVolume <= 100)
                                    return 100 * Math.pow(clampedVolume / 100, 2.8);
                                return clampedVolume;
                            }

                            width: participantList.width
                            height: 58

                            onCurrentVolumeChanged: {
                                if (readyForVolumeUpdates && !volumeMouse.pressed)
                                    previewVolume = currentVolume;
                            }
                            onBridgeErrorChanged: {
                                if (bridgeError && !volumeMouse.pressed)
                                    previewVolume = currentVolume;
                            }

                            Component.onCompleted: {
                                readyForVolumeUpdates = true;
                                previewVolume = currentVolume;
                            }

                            Rectangle {
                                id: participantAvatarFrame
                                width: 38
                                height: 38
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                radius: width / 2
                                color: participantRow.isSpeaking ? Theme.colors.success : Theme.colors.surfaceVariant
                                clip: true

                                Image {
                                    id: participantAvatarImage
                                    anchors.fill: parent
                                    anchors.margins: participantRow.isSpeaking ? 2 : 1
                                    source: participantRow.modelData.avatar || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: participantAvatarImage
                                    source: participantAvatarImage
                                    maskSource: Rectangle {
                                        width: participantAvatarImage.width
                                        height: participantAvatarImage.height
                                        radius: width / 2
                                        color: "white"
                                    }
                                    visible: participantAvatarImage.status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: (participantRow.modelData.name || "?").slice(0, 1).toUpperCase()
                                    color: Theme.colors.text
                                    font.family: Theme.font.overlay.family
                                    font.pixelSize: 12
                                    visible: participantAvatarImage.status !== Image.Ready
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openParticipantProfile(participantRow.modelData.id)
                                }
                            }

                            ColumnLayout {
                                anchors.left: participantAvatarFrame.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                RowLayout {
                                    id: participantHeader
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Row {
                                        id: participantIdentity
                                        Layout.fillWidth: false
                                        Layout.preferredWidth: implicitWidth
                                        spacing: 0

                                        Text {
                                            property string fullName: participantRow.modelData.name || "Usuario"
                                            text: fullName.length > 20 ? fullName.slice(0, 17) + "..." : fullName
                                            color: Theme.colors.text
                                            font: Theme.font.overlay
                                            wrapMode: Text.NoWrap
                                        }

                                        Item {
                                            id: resetUserButton
                                            width: 16
                                            height: 16

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰑐"
                                                color: Theme.colors.overlay
                                                font: Theme.font.icon
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !participantSettingProc.running
                                                acceptedButtons: Qt.LeftButton
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    participantSettingProc.command = [
                                                        SendaManager.binaryPath,
                                                        "discord",
                                                        "reset-user",
                                                        String(participantRow.modelData.id)
                                                    ];
                                                    participantSettingProc.running = true;
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    RowLayout {
                                        id: participantActions
                                        spacing: 4

                                        Text {
                                            visible: participantRow.isSelfMuted || participantRow.isServerMuted
                                            text: "󰍭"
                                            color: participantRow.isServerMuted ? Theme.colors.error : Theme.colors.overlay
                                            font: Theme.font.base
                                        }

                                        Text {
                                            visible: participantRow.isSelfDeaf || participantRow.isServerDeaf
                                            text: "󰋋"
                                            color: participantRow.isServerDeaf ? Theme.colors.error : Theme.colors.overlay
                                            font: Theme.font.base
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 22
                                            color: "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: participantRow.isMuted ? "󰖁" : "󰕾"
                                                color: participantRow.isMuted ? Theme.colors.error : Theme.colors.text
                                                font: Theme.font.base
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !participantSettingProc.running
                                                acceptedButtons: Qt.LeftButton
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    participantSettingProc.command = [
                                                        SendaManager.binaryPath,
                                                        "discord",
                                                        "set-user-mute",
                                                        String(participantRow.modelData.id),
                                                        participantRow.isMuted ? "false" : "true"
                                                    ];
                                                    participantSettingProc.running = true;
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 7

                                    Item {
                                        id: volumeTrack
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 16

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            height: 4
                                            radius: 2
                                            color: Theme.colors.surfaceVariant

                                            Rectangle {
                                                width: parent.width * (participantRow.previewVolume / 200)
                                                height: parent.height
                                                radius: parent.radius
                                                color: Theme.colors.primary
                                            }
                                        }

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: width / 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.max(0, Math.min(parent.width - width,
                                                parent.width * (participantRow.previewVolume / 200) - width / 2))
                                            color: Theme.colors.primary
                                        }

                                        MouseArea {
                                            id: volumeMouse
                                            anchors.fill: parent
                                            enabled: !participantSettingProc.running
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                            function updatePreview(mouseX) {
                                                const ratio = Math.max(0, Math.min(1, mouseX / width));
                                                participantRow.previewVolume = Math.round(ratio * 200);
                                            }

                                            onPressed: mouse => updatePreview(mouse.x)
                                            onPositionChanged: mouse => {
                                                if (pressed) updatePreview(mouse.x);
                                            }
                                            onReleased: mouse => {
                                                updatePreview(mouse.x);
                                                participantSettingProc.command = [
                                                    SendaManager.binaryPath,
                                                    "discord",
                                                    "set-user-volume",
                                                    String(participantRow.modelData.id),
                                                    participantRow.toRpcVolume(participantRow.previewVolume).toFixed(2)
                                                ];
                                                participantSettingProc.running = true;
                                            }
                                            onCanceled: participantRow.previewVolume = participantRow.currentVolume
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 44
                                        text: `${Math.round(participantRow.previewVolume)}%`
                                        color: Theme.colors.overlay
                                        font: Theme.font.overlay
                                        horizontalAlignment: Text.AlignRight
                                        ToolTip.text: "Volumen RPC de Discord (100 = valor predeterminado)"
                                    }
                                }
                            }

                            Process {
                                id: participantSettingProc
                                running: false
                                command: []
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        if (text.trim()) {
                                            root.hint = text.trim();
                                            participantRow.previewVolume = participantRow.currentVolume;
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
