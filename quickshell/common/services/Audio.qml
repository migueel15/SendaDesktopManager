pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var nodes: Pipewire.nodes.values.reduce((acc, node) => {
        if (!node.isStream) {
            if (node.isSink) {
                acc.sinks.push(node);
            } else if (node.audio) {
                acc.sources.push(node);
            }
        }
        return acc;
    }, {
        "sources": [],
        "sinks": []
    })

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property list<PwNode> sinks: nodes.sinks
    readonly property list<PwNode> sources: nodes.sources

    readonly property alias volume: root._volume
    property real _volume: root.normalizeVolume(sink?.audio?.volume)
    property real _observedOutputVolume: root.normalizeVolume(sink?.audio?.volume)

    property string audioTheme: "freedesktop"

    readonly property alias muted: root._muted
    property bool _muted: !!sink?.audio?.muted
    property bool _observedOutputMuted: !!sink?.audio?.muted

    readonly property alias inputVolume: root._inputVolume
    property real _inputVolume: source?.audio?.volume ?? 0

    readonly property alias inputMuted: root._inputMuted
    property bool _inputMuted: !!source?.audio?.muted

    readonly property real stepVolume: 0.05
    readonly property bool outputUsesWpctlFallback: root.isVolumeInvalid(root.sink?.audio?.volume)
    property real pendingOutputVolume: root._volume
    property bool pendingOutputMuted: root._muted
    property bool outputVolumeDirty: false
    property bool outputMuteDirty: false

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources]
    }

    Timer {
        id: outputVolumePollTimer
        interval: 1500
        running: root.outputUsesWpctlFallback
        repeat: true

        onTriggered: {
            if (!outputVolumeReader.running) {
                outputVolumeReader.running = true;
            }
        }
    }

    Timer {
        id: outputRefreshTimer
        interval: 150
        running: false
        repeat: false

        onTriggered: {
            if (root.outputUsesWpctlFallback && !outputVolumeReader.running) {
                outputVolumeReader.running = true;
            }
        }
    }

    Process {
        id: outputVolumeReader
        running: false
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            onStreamFinished: root.updateOutputStateFromWpctl(text)
        }
    }

    Timer {
        id: outputApplyTimer
        interval: 75
        running: false
        repeat: false

        onTriggered: root.applyPendingOutputState()
    }

    onSinkChanged: {
        root._volume = root.normalizeVolume(root.sink?.audio?.volume, root._volume);
        root._muted = !!root.sink?.audio?.muted;
        root._observedOutputVolume = root._volume;
        root._observedOutputMuted = root._muted;
        root.pendingOutputVolume = root._volume;
        root.pendingOutputMuted = root._muted;

        if (root.outputUsesWpctlFallback && !outputVolumeReader.running) {
            outputVolumeReader.running = true;
        }
    }

    onOutputUsesWpctlFallbackChanged: {
        if (root.outputUsesWpctlFallback && !outputVolumeReader.running) {
            outputVolumeReader.running = true;
        }
    }

    Connections {
        target: root.sink?.audio ? root.sink?.audio : null

        function onVolumeChanged() {
            var vol = (root.sink?.audio.volume ?? 0);
            if (isNaN(vol)) {
                return;
            }
            root._observedOutputVolume = vol;
            root._volume = vol;
        }

        function onMutedChanged() {
            const muted = (root.sink?.audio.muted ?? true);
            root._observedOutputMuted = muted;
            root._muted = muted;
        }
    }

    Connections {
        target: root.source?.audio ? root.source?.audio : null

        function onVolumeChanged() {
            var vol = (root.source?.audio.volume ?? 0);
            if (isNaN(vol)) {
                return;
            }
            root._inputVolume = vol;
        }

        function onMutedChanged() {
            root._inputMuted = (root.source?.audio.muted ?? true);
        }
    }

    function increaseVolume() {
        setVolume(volume + stepVolume);
    }

    function decreaseVolume() {
        setVolume(volume - stepVolume);
    }

    function setVolume(newVolume: real) {
        const clampedVolume = root.normalizeVolume(newVolume, root._volume);

        if (root.outputUsesWpctlFallback) {
            root._muted = false;
            root._volume = clampedVolume;
            root.pendingOutputVolume = clampedVolume;
            root.outputVolumeDirty = true;

            if (root._observedOutputMuted || root.pendingOutputMuted) {
                root.pendingOutputMuted = false;
                root.outputMuteDirty = true;
            }

            outputApplyTimer.restart();
            return;
        }

        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = clampedVolume;
        } else {}
    }

    function setOutputMuted(muted: bool) {
        if (root.outputUsesWpctlFallback) {
            root._muted = muted;
            root.pendingOutputMuted = muted;
            root.outputMuteDirty = true;
            outputApplyTimer.restart();
            return;
        }

        if (sink?.ready && sink?.audio) {
            sink.audio.muted = muted;
        } else {}
    }

    function increaseInputVolume() {
        setInputVolume(inputVolume + stepVolume);
    }

    function decreaseInputVolume() {
        setInputVolume(inputVolume - stepVolume);
    }

    function setInputVolume(newVolume: real) {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1.0, newVolume));
        } else {}
    }

    function setInputMuted(muted: bool) {
        if (source?.ready && source?.audio) {
            source.audio.muted = muted;
        }
    }

    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
        root._volume = root.normalizeVolume(newSink?.audio?.volume, root._volume);
        root._muted = !!newSink?.audio?.muted;
        root._observedOutputVolume = root._volume;
        root._observedOutputMuted = root._muted;
        root.pendingOutputVolume = root._volume;
        root.pendingOutputMuted = root._muted;
        outputRefreshTimer.restart();
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
        root._inputVolume = newSource?.audio?.volume ?? 0;
        root._inputMuted = !!newSource?.audio?.muted;
    }

    function getOutputIcon() {
        if (muted) {
            return "volume-mute";
        }
        return (volume <= Number.EPSILON) ? "volume-zero" : (volume <= 0.5) ? "volume-low" : "volume-high";
    }

    function getInputIcon() {
        if (inputMuted) {
            return "microphone-mute";
        }
        return (inputVolume <= Number.EPSILON) ? "microphone-mute" : "microphone";
    }

    readonly property string icon: {
        if (root.muted) {
            return "󰝟";
        }

        if (root.volume < 0.33)
            return "󰕿";
        if (root.volume < 0.66)
            return "󰖀";

        return "󰕾";
    }

    function playSystemSound(soundName) {
        const soundPath = `/usr/share/sounds/${root.audioTheme}/stereo/${soundName}.oga`;
        const command = ["ffplay", "-nodisp", "-autoexit", soundPath];
        Quickshell.execDetached(command);
    }

    function muteSink() {
        root.setOutputMuted(!root.muted);
    }

    function isVolumeInvalid(value): bool {
        return value === undefined || value === null || isNaN(value) || !isFinite(value);
    }

    function normalizeVolume(value, fallback): real {
        const fallbackVolume = fallback === undefined ? 0 : fallback;

        if (root.isVolumeInvalid(value)) {
            return Math.max(0, Math.min(1.0, fallbackVolume));
        }

        return Math.max(0, Math.min(1.0, value));
    }

    function applyPendingOutputState() {
        if (!root.outputUsesWpctlFallback) {
            root.outputVolumeDirty = false;
            root.outputMuteDirty = false;
            return;
        }

        const commands = [];

        if (root.outputMuteDirty && !root.pendingOutputMuted) {
            commands.push("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0");
        }

        if (root.outputVolumeDirty) {
            commands.push(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${root.pendingOutputVolume.toFixed(3)}`);
        }

        if (root.outputMuteDirty && root.pendingOutputMuted) {
            commands.push("wpctl set-mute @DEFAULT_AUDIO_SINK@ 1");
        }

        root.outputVolumeDirty = false;
        root.outputMuteDirty = false;

        if (commands.length > 0) {
            Quickshell.execDetached(["bash", "-lc", commands.join(" && ")]);
            outputRefreshTimer.restart();
        }
    }

    function updateOutputStateFromWpctl(text: string) {
        const volumeMatch = text.match(/Volume:\s*([0-9]*\.?[0-9]+)/);

        if (volumeMatch) {
            const volume = root.normalizeVolume(parseFloat(volumeMatch[1]), root._volume);
            root._observedOutputVolume = volume;
            root._volume = volume;
        }

        const muted = text.indexOf("[MUTED]") !== -1;
        root._observedOutputMuted = muted;
        root._muted = muted;
    }

    function checkActiveDevices() {
        const audios = Pipewire.nodes.values.filter(n => n.isSink && n.isStream !== true && n.audio != null);
        const priorityOrder = ["", ""];

        print(audios.map(s => s.description));
    }

    function getDisplayName(node: PwNode): string {
        if (node.nickname === "BenQ EX2710Q")
            return "Monitor Principal";

        if (node.nickname === "PRO X Wireless Gaming Headset")
            return "Logitech PRO X";

        if (node.description === "LE-Beats Studio Buds + de Miguel")
            return "Beats Studio Buds +";

        return node.nickname || node.description || "Unknown device";
    }
}
