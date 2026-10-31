import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Scope {
    id: root

    readonly property var player: {
        const players = Mpris.players.values ?? [];
        return players.find(item => item.playbackState === MprisPlaybackState.Playing) ?? players[0] ?? null;
    }

    // `senda media` calls these from the media keys.
    IpcHandler {
        target: "media"

        function playPause() {
            if (root.player?.canTogglePlaying)
                root.player.togglePlaying();
        }

        function next() {
            if (root.player?.canGoNext)
                root.player.next();
        }

        function previous() {
            if (root.player?.canGoPrevious)
                root.player.previous();
        }
    }
}
