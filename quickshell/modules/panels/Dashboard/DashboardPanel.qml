import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris

import qs.common
import qs.common.components
import qs.modules.panels.Dashboard
import qs.services

SendaPanel {
    id: root
    name: "dashboard"

    padding: 16
    targetWidth: 700
    targetHeight: 480

    targetX: parent.width / 2 - root.width / 2
    targetY: 45

    function isSpotifyPlayer(player) {
        if (!player) return false;
        const desktopEntry = (player.desktopEntry ?? "").toLowerCase();
        const identity = (player.identity ?? "").toLowerCase();
        const name = (player.name ?? "").toLowerCase();
        const serviceName = (player.serviceName ?? "").toLowerCase();
        return desktopEntry === "spotify" || identity.includes("spotify")
            || name.includes("spotify") || serviceName.includes("spotify");
    }

    readonly property var player: {
        const players = Mpris.players.values ?? [];
        const spotifyPlayers = players.filter(item => root.isSpotifyPlayer(item));
        return spotifyPlayers.find(item => item.playbackState === MprisPlaybackState.Playing)
            ?? spotifyPlayers.find(item => item.trackTitle || item.trackArtist)
            ?? players.find(item => item.playbackState === MprisPlaybackState.Playing)
            ?? players.find(item => item.trackTitle || item.trackArtist)
            ?? null;
    }
    readonly property string greeting: {
        const hour = systemClock.date.getHours();
        if (hour < 12) return "Buenos días";
        if (hour < 20) return "Buenas tardes";
        return "Buenas noches";
    }
    readonly property string networkLabel: Network.wifiConnected ? "Wi-Fi conectado"
        : Network.ethernetConnected ? "Ethernet conectado" : "Sin conexión de red";
    readonly property string networkIcon: Network.wifiConnected ? "󰖩"
        : Network.ethernetConnected ? "󰈀" : "󰖪";

    function focusSpotify() {
        Quickshell.execDetached([SendaManager.binaryPath, "window", "focus", "spotify"]);
    }

    function formatTrackTime(seconds) {
        const totalSeconds = Math.max(0, Math.floor(seconds || 0));
        const totalMinutes = Math.floor(totalSeconds / 60);
        const remainder = String(totalSeconds % 60).padStart(2, "0");
        if (totalMinutes >= 60) {
            return `${Math.floor(totalMinutes / 60)}:${String(totalMinutes % 60).padStart(2, "0")}:${remainder}`;
        }
        return `${totalMinutes}:${remainder}`;
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    Timer {
        interval: 1000
        repeat: true
        running: !!root.player && root.player.playbackState === MprisPlaybackState.Playing && root.player.positionSupported && !seekArea.pressed
        onTriggered: root.player?.positionChanged()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 166
            radius: Theme.rounding.normal
            color: Theme.colors.surface
            border.width: 1
            border.color: Theme.colors.surfaceVariant

            RowLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: root.greeting
                        color: Theme.colors.primary
                        font.family: Theme.font.title.family
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Text {
                        text: Qt.formatDate(systemClock.date, "dddd, d 'de' MMMM")
                        color: Theme.colors.overlay
                        font.family: Theme.font.overlay.family
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: "Un buen día empieza a tu ritmo."
                        color: Theme.colors.text
                        font.family: Theme.font.base.family
                        font.pixelSize: 14
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Theme.colors.surfaceVariant
                }

                Item {
                    Layout.preferredWidth: 190

                    Text {
                        anchors.centerIn: parent
                        text: Qt.formatTime(systemClock.date, "HH:mm")
                        color: Theme.colors.text
                        font.family: Theme.font.title.family
                        font.pixelSize: 58
                        font.weight: Font.Bold
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.rounding.normal
                color: Theme.colors.surface
                border.width: 1
                border.color: DorlabTasks.hasActiveTask ? Theme.colors.primary : Theme.colors.surfaceVariant

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰃰"
                            color: Theme.colors.secondary
                            font.family: Theme.font.title.family
                            font.pixelSize: 20
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "EN LO QUE ESTÁS"
                            color: Theme.colors.overlay
                            font.family: Theme.font.overlay.family
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                        Rectangle {
                            visible: DorlabTasks.hasActiveTask
                            width: 7
                            height: 7
                            radius: 4
                            color: Theme.colors.success
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        text: DorlabTasks.hasTrackedTask
                            ? DorlabTasks.trackedTaskTitle
                            : "Espacio para tu próxima idea"
                        color: Theme.colors.text
                        font.family: Theme.font.title.family
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: DorlabTasks.hasTrackedTask
                            ? `${DorlabTasks.hasActiveTask ? "EN MARCHA" : "EN PAUSA"}  ·  ${DorlabTasks.hasActiveTask ? DorlabTasks.formatDuration(DorlabTasks.activeElapsedSeconds) : "reanuda cuando quieras"}`
                            : "Un paso pequeño también cuenta."
                        color: DorlabTasks.hasActiveTask ? Theme.colors.success : Theme.colors.overlay
                        font.family: Theme.font.overlay.family
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 154
                    radius: Theme.rounding.normal
                    color: Theme.colors.surface
                    border.width: 1
                    border.color: Theme.colors.surfaceVariant

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 0

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                            Layout.preferredWidth: 285
                            Layout.preferredHeight: 118
                            spacing: 11

                            Rectangle {
                                Layout.preferredWidth: 118
                                Layout.preferredHeight: 118
                                radius: 24
                                color: Theme.colors.surfaceVariant
                                clip: true

                                Image {
                                    id: albumArt
                                    width: parent.width
                                    height: parent.height
                                    source: root.player?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: false
                                }
                                OpacityMask {
                                    anchors.fill: parent
                                    source: albumArt
                                    maskSource: Rectangle {
                                        width: 118
                                        height: 118
                                        radius: 24
                                        color: "white"
                                    }
                                    visible: albumArt.status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝚"
                                    color: Theme.colors.overlay
                                    font.family: Theme.font.title.family
                                    font.pixelSize: 27
                                    visible: albumArt.status !== Image.Ready
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.focusSpotify()
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 156
                                Layout.preferredHeight: 118
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.player?.trackTitle || "Silencio también es música"
                                    color: Theme.colors.text
                                    font.family: Theme.font.title.family
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.player?.trackArtist || "No hay reproducción activa"
                                    color: Theme.colors.overlay
                                    font.family: Theme.font.overlay.family
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Item { Layout.fillHeight: true }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    visible: !!root.player && root.player.lengthSupported

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.formatTrackTime(seekArea.pressed ? seekArea.previewPosition : (root.player?.position ?? 0))
                                            color: Theme.colors.overlay
                                            font.family: Theme.font.overlay.family
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            text: root.formatTrackTime(root.player?.length ?? 0)
                                            color: Theme.colors.overlay
                                            font.family: Theme.font.overlay.family
                                            font.pixelSize: 11
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 4
                                        radius: 2
                                        color: Theme.colors.surfaceVariant

                                        Rectangle {
                                            width: parent.width * (root.player?.length > 0
                                                ? Math.max(0, Math.min(1, (seekArea.pressed ? seekArea.previewPosition : root.player.position) / root.player.length)) : 0)
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.colors.primary
                                        }

                                        MouseArea {
                                            id: seekArea
                                            anchors.centerIn: parent
                                            width: parent.width
                                            height: 18
                                            enabled: !!root.player && root.player.canSeek && root.player.positionSupported && root.player.length > 0
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            property real previewPosition: 0

                                            function updatePreview(mouseX) {
                                                const ratio = Math.max(0, Math.min(1, mouseX / width));
                                                previewPosition = ratio * root.player.length;
                                            }

                                            onPressed: mouse => updatePreview(mouse.x)
                                            onPositionChanged: mouse => {
                                                if (pressed) updatePreview(mouse.x);
                                            }
                                            onReleased: mouse => {
                                                updatePreview(mouse.x);
                                                root.player.position = previewPosition;
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 5

                                    Repeater {
                                        model: [
                                            { icon: "󰒮", enabled: !!root.player?.canGoPrevious, action: () => root.player?.previous() },
                                            { icon: root.player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊", enabled: !!root.player && (root.player.canPlay || root.player.canPause), action: () => {
                                                if (!root.player) return;
                                                if (root.player.playbackState === MprisPlaybackState.Playing && root.player.canPause) root.player.pause();
                                                else if (root.player.canPlay) root.player.play();
                                            } },
                                            { icon: "󰒭", enabled: !!root.player?.canGoNext, action: () => root.player?.next() }
                                        ]

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.preferredWidth: 30
                                            Layout.preferredHeight: 27
                                            radius: Theme.rounding.small
                                            color: controlMouse.pressed ? Theme.colors.surfaceVariant : "transparent"
                                            opacity: modelData.enabled ? 1 : 0.35

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                color: Theme.colors.text
                                                font.family: Theme.font.title.family
                                                font.pixelSize: 17
                                            }
                                            MouseArea {
                                                id: controlMouse
                                                anchors.fill: parent
                                                enabled: modelData.enabled
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: modelData.action()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.rounding.normal
                    color: Theme.colors.surface
                    border.width: 1
                    border.color: Theme.colors.surfaceVariant

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Text {
                            text: "TU ESPACIO"
                            color: Theme.colors.overlay
                            font.family: Theme.font.overlay.family
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 9
                            Text {
                                text: Battery.isLaptop ? Battery.icon : root.networkIcon
                                color: Battery.isLaptop && Battery.batteryPercentage < 0.2 ? Theme.colors.warning : Theme.colors.primary
                                font.family: Theme.font.title.family
                                font.pixelSize: 18
                            }
                            Text {
                                Layout.fillWidth: true
                                text: Battery.isLaptop ? `${Battery.label}${Battery.isCharging ? " · cargando" : ""}` : root.networkLabel
                                color: Theme.colors.text
                                font.family: Theme.font.overlay.family
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 9
                            Text {
                                text: Audio.muted ? "󰖁" : "󰕾"
                                color: Audio.muted ? Theme.colors.warning : Theme.colors.secondary
                                font.family: Theme.font.title.family
                                font.pixelSize: 18
                            }
                            Text {
                                Layout.fillWidth: true
                                text: Audio.muted ? "Audio silenciado" : `Volumen  ${Math.round(Audio.volume * 100)}%`
                                color: Theme.colors.text
                                font.family: Theme.font.overlay.family
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
