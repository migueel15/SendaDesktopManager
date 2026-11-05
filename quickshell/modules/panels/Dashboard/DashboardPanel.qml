import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris

import qs.common
import qs.common.components.controls
import qs.common.components
import qs.modules.panels.Dashboard
import qs.services

// Dashboard content. The overlay hosts it in a ZendaPanel.
Item {
    id: root

    // Size the content needs; the host panel adds its padding.
    readonly property real contentWidth: Math.max(700, dashboardLayout.implicitWidth)
    readonly property real contentHeight: 720

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
    // Login name of the session, with its first letter capitalized.
    readonly property string userName: {
        const user = Quickshell.env("USER") ?? "";
        return user.charAt(0).toUpperCase() + user.slice(1);
    }

    function focusSpotify() {
        Quickshell.execDetached([ZendaManager.binaryPath, "window", "focus", "spotify"]);
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
        id: dashboardLayout
        anchors.fill: parent
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 166
            radius: Theme.card.radius
            color: Theme.card.fill
            border.width: Theme.card.borderWidth
            border.color: Theme.card.borderColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: root.userName ? `${root.greeting}, ${root.userName}` : root.greeting
                        color: Theme.colors.primary
                        font.family: Theme.font.title.family
                        font.pixelSize: Theme.scaled(18)
                        font.weight: Font.Bold
                    }
                    Text {
                        text: Theme.locale.toString(systemClock.date, "dddd, d 'de' MMMM")
                        color: Theme.colors.overlay
                        font.family: Theme.font.overlay.family
                    }
                    Item { Layout.fillHeight: true }
                    DayLine {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                    }
                }

                Item {
                    Layout.preferredWidth: 190

                    Text {
                        anchors.centerIn: parent
                        text: Theme.locale.toString(systemClock.date, "HH:mm")
                        color: Theme.colors.text
                        font.family: Theme.font.title.family
                        font.pixelSize: Theme.scaled(58)
                        font.weight: Font.Bold
                    }
                }
            }
        }

        CalendarCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 232
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            AgendaCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 154
                    radius: Theme.card.radius
                    color: Theme.card.fill
                    border.width: Theme.card.borderWidth
                    border.color: Theme.card.borderColor

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
                                radius: Theme.rounding.card
                                color: Theme.colors.surfaceVariant
                                clip: true

                                Image {
                                    id: albumArt
                                    width: parent.width
                                    height: parent.height
                                    source: root.player?.trackArtUrl ?? ""
                                    sourceSize: Qt.size(Math.ceil(width * (QsWindow.window?.screen?.devicePixelRatio ?? 1)), Math.ceil(height * (QsWindow.window?.screen?.devicePixelRatio ?? 1)))
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
                                        radius: Theme.rounding.card
                                        color: "white"
                                    }
                                    visible: albumArt.status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝚"
                                    color: Theme.colors.overlay
                                    font.family: Theme.font.title.family
                                    font.pixelSize: Theme.scaled(27)
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
                                    font.pixelSize: Theme.scaled(14)
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.player?.trackArtist || "No hay reproducción activa"
                                    color: Theme.colors.overlay
                                    font.family: Theme.font.overlay.family
                                    font.pixelSize: Theme.scaled(11)
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
                                            font.pixelSize: Theme.scaled(11)
                                        }
                                        Text {
                                            text: root.formatTrackTime(root.player?.length ?? 0)
                                            color: Theme.colors.overlay
                                            font.family: Theme.font.overlay.family
                                            font.pixelSize: Theme.scaled(11)
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 6
                                        radius: Theme.rounding.full
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

                                        delegate: ZendaIconButton {
                                            required property var modelData
                                            required property int index
                                            // Play/pause is the main action: larger and tonal.
                                            size: index === 1 ? Theme.scaled(36) : Theme.scaled(30)
                                            tonal: index === 1
                                            active: index === 1 && root.player?.playbackState === MprisPlaybackState.Playing
                                            enabled: modelData.enabled
                                            icon: modelData.icon
                                            onClicked: modelData.action()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                WeatherCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
