import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris

import qs.common
import qs.services
import qs.common.components.barextension as BarComponents

Rectangle {
    id: root

    property bool expanded: false

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
        Quickshell.execDetached([SendaManager.binaryPath, "window", "focus", "spotify"]);
    }

    function openSpotifyUrl(url) {
        if (url) Quickshell.execDetached(["spotify", `--uri=${url}`]);
    }

    function openSpotifyArtist() {
        const artist = root.activePlayer?.trackArtist || "";
        if (artist) root.openSpotifyUrl(`spotify:search:${encodeURIComponent(artist)}`);
    }

    function openSpotifyTrack() {
        const metadata = root.activePlayer?.metadata ?? {};
        const trackId = String(metadata["mpris:trackid"] ?? metadata["xesam:url"] ?? "");
        const spotifyTrack = trackId.match(/(?:spotify:track:|\/track\/)([A-Za-z0-9]+)/);
        if (spotifyTrack) {
            root.openSpotifyUrl(`spotify:track:${spotifyTrack[1]}`);
            return;
        }

        const title = root.activePlayer?.trackTitle || "";
        const artist = root.activePlayer?.trackArtist || "";
        const query = [title, artist].filter(Boolean).join(" ");
        if (query) root.openSpotifyUrl(`spotify:search:${encodeURIComponent(query)}`);
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

    function itemXInWindow(item, windowContentItem) {
        let x = 0;
        let current = item;
        while (current && current !== windowContentItem) {
            x += current.x;
            current = current.parent;
        }
        return current === windowContentItem ? x : 0;
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
    readonly property bool hasTimeline: !!activePlayer && activePlayer.positionSupported && activePlayer.lengthSupported && activePlayer.length > 0

    implicitWidth: hasTrack ? controls.implicitWidth + 12 : 0
    height: parent.height * 0.8
    color: Theme.colors.surface
    radius: Theme.rounding.normal
    visible: hasTrack

    onHasTrackChanged: {
        if (!hasTrack) root.expanded = false;
    }

    HoverHandler {
        id: widgetHover
        onHoveredChanged: {
            if (hovered) root.expanded = true;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.expanded && root.isPlaying && root.hasTimeline && !timelineSeek.pressed
        onTriggered: root.activePlayer?.positionChanged()
    }

    RowLayout {
        id: controls
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 2

        Rectangle {
            id: spotifyButton
            Layout.preferredWidth: 24
            Layout.preferredHeight: parent.height
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: ""
                color: "#1DB954"
                font: Theme.font.base
            }

            MouseArea {
                id: spotifyMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusSpotify()
            }
        }

        Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: parent.height
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰒮"
                color: root.activePlayer?.canGoPrevious ? Theme.colors.text : Theme.colors.overlay
                font: Theme.font.base
            }

            MouseArea {
                id: previousMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.activePlayer?.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.activePlayer?.canGoPrevious)
                        root.activePlayer.previous();
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
                color: (root.activePlayer?.canPlay || root.activePlayer?.canPause) ? Theme.colors.text : Theme.colors.overlay
                font: Theme.font.base
            }

            MouseArea {
                id: playMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: (root.activePlayer?.canPlay || root.activePlayer?.canPause) ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!root.activePlayer)
                        return;

                    if (root.isPlaying && root.activePlayer.canPause) {
                        root.activePlayer.pause();
                    } else if (!root.isPlaying && root.activePlayer.canPlay) {
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
                color: root.activePlayer?.canGoNext ? Theme.colors.text : Theme.colors.overlay
                font: Theme.font.base
            }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.activePlayer?.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.activePlayer?.canGoNext)
                        root.activePlayer.next();
                }
            }
        }
    }

    PopupWindow {
        id: trackExtension

        anchor.window: root.QsWindow.window
        anchor.rect.x: {
            const window = root.QsWindow.window;
            if (!window) return 0;
            // Read ancestor x properties directly so QML re-evaluates this when the layout moves the widget.
            return root.itemXInWindow(root, window.contentItem)
                + root.width / 2 - trackExtension.width / 2;
        }
        anchor.rect.y: root.QsWindow.window
                ? root.QsWindow.window.contentItem.height
                : 0
        anchor.rect.width: 1
        anchor.rect.height: 1

        width: 280
        implicitWidth: 280
        // Size the window for the open extension, so the unfold animates inside it
        // instead of resizing the Wayland surface on every frame. Growing the
        // window while shrinking keeps a resize animation from being cut off.
        implicitHeight: Math.max(1, trackExtensionContent.expandedHeight, trackExtensionContent.height)
        // Let clicks below the visible shape reach the windows underneath.
        mask: Region {
            item: trackExtensionContent
        }
        visible: root.expanded || trackExtensionContent.height > 0.01
        color: "transparent"

        BarComponents.BarExtension {
            id: trackExtensionContent
            // Hide the last pixels under the bar, without moving the window.
            y: -collapseLift
            width: trackExtension.width
            expanded: root.expanded
            expandedHeight: 92
            conflictGroup: "tray-popups"
            autoHideStartsOnExpand: true
            autoHideDelay: 500
            autoHidePaused: widgetHover.hovered
            onCloseRequested: root.expanded = false

            Column {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 6

                RowLayout {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 6
                        color: Theme.colors.surfaceVariant
                        clip: true

                        Image {
                            id: trackArt
                            width: parent.width
                            height: parent.height
                            source: root.activePlayer?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: trackArt
                            maskSource: Rectangle {
                                width: 40
                                height: 40
                                radius: 6
                                color: "white"
                            }
                            visible: trackArt.status === Image.Ready
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openSpotifyTrack()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: root.activePlayer?.trackTitle || "Sin título"
                            color: Theme.colors.text
                            font.family: Theme.font.overlay.family
                            font.pixelSize: Theme.scaled(14)
                            font.weight: Font.Bold
                            elide: Text.ElideRight

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openSpotifyTrack()
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.activePlayer?.trackArtist || "Artista desconocido"
                            color: Theme.colors.overlay
                            font: Theme.font.overlay
                            elide: Text.ElideRight

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openSpotifyArtist()
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4
                    // Stays visible while a track is shown, at 0 until the duration is known.
                    visible: root.hasTrack

                    RowLayout {
                        width: parent.width

                        Text {
                            text: root.formatTrackTime(timelineSeek.pressed
                                ? timelineSeek.previewPosition
                                : (root.activePlayer?.position ?? 0))
                            color: Theme.colors.overlay
                            font: Theme.font.overlay
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.formatTrackTime(root.activePlayer?.length ?? 0)
                            color: Theme.colors.overlay
                            font: Theme.font.overlay
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.colors.surfaceVariant

                        Rectangle {
                            width: parent.width * (root.activePlayer?.length > 0
                                ? Math.max(0, Math.min(1, (timelineSeek.pressed
                                    ? timelineSeek.previewPosition
                                    : root.activePlayer.position) / root.activePlayer.length)) : 0)
                            height: parent.height
                            radius: parent.radius
                            color: Theme.colors.primary
                        }

                        MouseArea {
                            id: timelineSeek
                            anchors.centerIn: parent
                            width: parent.width
                            height: 18
                            enabled: root.activePlayer?.canSeek && root.hasTimeline
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            property real previewPosition: 0

                            function updatePreview(mouseX) {
                                const ratio = Math.max(0, Math.min(1, mouseX / width));
                                previewPosition = ratio * root.activePlayer.length;
                            }

                            onPressed: mouse => updatePreview(mouse.x)
                            onPositionChanged: mouse => {
                                if (pressed) updatePreview(mouse.x);
                            }
                            onReleased: mouse => {
                                updatePreview(mouse.x);
                                root.activePlayer.position = previewPosition;
                            }
                        }
                    }
                }
            }
        }
    }
}
