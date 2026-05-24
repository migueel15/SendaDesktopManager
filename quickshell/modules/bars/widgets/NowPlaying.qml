import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

import qs.common

Rectangle {
    id: root

    function isSpotifyPlayer(player) {
        if (!player) {
            return false;
        }

        const desktopEntry = (player.desktopEntry ?? "").toLowerCase();
        const identity = (player.identity ?? "").toLowerCase();
        const name = (player.name ?? "").toLowerCase();
        const serviceName = (player.serviceName ?? "").toLowerCase();

        return desktopEntry === "spotify" || identity.includes("spotify") || name.includes("spotify") || serviceName.includes("spotify");
    }

    function focusSpotify() {
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:spotify"]);
    }

    readonly property var activePlayer: {
        const players = Mpris.players.values ?? [];
        if (players.length === 0) {
            return null;
        }

        const spotifyPlayers = players.filter(player => root.isSpotifyPlayer(player));
        if (spotifyPlayers.length === 0) {
            return null;
        }

        const playingPlayer = spotifyPlayers.find(player => player.playbackState === MprisPlaybackState.Playing);
        if (playingPlayer) {
            return playingPlayer;
        }

        const pausedPlayer = spotifyPlayers.find(player => player.trackTitle || player.trackArtist);
        return pausedPlayer ?? spotifyPlayers[0];
    }

    readonly property bool hasTrack: !!activePlayer && (!!activePlayer.trackTitle || !!activePlayer.trackArtist)
    readonly property bool isPlaying: !!activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    implicitWidth: hasTrack ? layout.implicitWidth + 24 : 0
    height: parent.height * 0.8
    radius: 10
    color: Theme.colors.background
    visible: hasTrack

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: parent.height
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰒮"
                color: root.isPlaying ? Theme.colors.overlay : Theme.colors.surfaceVariant
                font: Theme.font.base
                opacity: root.activePlayer?.canGoPrevious ? 1 : 0.4
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: root.activePlayer?.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.activePlayer?.canGoPrevious) {
                        root.activePlayer.previous();
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: parent.height
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: root.isPlaying ? "󰏤" : "󰐊"
                color: root.isPlaying ? Theme.colors.overlay : Theme.colors.surfaceVariant
                font: Theme.font.base
                opacity: (root.activePlayer?.canPlay || root.activePlayer?.canPause) ? 1 : 0.4
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: (root.activePlayer?.canPlay || root.activePlayer?.canPause) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!root.activePlayer) {
                        return;
                    }

                    if (root.isPlaying && root.activePlayer.canPause) {
                        root.activePlayer.pause();
                        return;
                    }

                    if (!root.isPlaying && root.activePlayer.canPlay) {
                        root.activePlayer.play();
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: parent.height
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰒭"
                color: root.isPlaying ? Theme.colors.overlay : Theme.colors.surfaceVariant
                font: Theme.font.base
                opacity: root.activePlayer?.canGoNext ? 1 : 0.4
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: root.activePlayer?.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.activePlayer?.canGoNext) {
                        root.activePlayer.next();
                    }
                }
            }
        }

        Text {
            Layout.preferredWidth: 240
            Layout.maximumWidth: 320
            text: {
                if (!root.activePlayer) {
                    return "";
                }

                if (root.activePlayer.trackTitle && root.activePlayer.trackArtist) {
                    return `${root.activePlayer.trackTitle} - ${root.activePlayer.trackArtist}`;
                }

                return root.activePlayer.trackTitle || root.activePlayer.trackArtist;
            }
            color: root.isPlaying ? Theme.colors.overlay : Theme.colors.surfaceVariant
            font: Theme.font.base
            elide: Text.ElideRight

            MouseArea {
                anchors.fill: parent
                cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: !!root.activePlayer
                onClicked: root.focusSpotify()
            }
        }
    }
}
