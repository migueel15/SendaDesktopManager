pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services

// Records a shortcut by pressing it. While recording, Hyprland is switched to
// Senda's empty capture submap so that existing binds do not fire.
ColumnLayout {
    id: root

    // "lock", "dictation" or "screenshot": the Senda shortcut this control edits.
    property string target: "lock"
    property string value: ""
    property string defaultValue: ""

    // idle, starting, recording, checking or confirm
    property string phase: "idle"
    property string candidate: ""
    property var conflicts: []
    property string message: ""

    readonly property string flag: "--" + target + "-shortcut"

    spacing: Theme.spacing.xs

    function pretty(shortcut) {
        if (!shortcut) return "";
        const names = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" };
        return shortcut.split(" + ").map(part => {
            if (names[part]) return names[part];
            if (part.toLowerCase() === "ntilde") return "Ñ";
            return part.length === 1 ? part.toUpperCase() : part.charAt(0).toUpperCase() + part.slice(1);
        }).join(" + ");
    }

    // Maps a Qt key to the Hyprland key name, or "" when it is not supported.
    function keyName(key) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key).toLowerCase();
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24) return "F" + (key - Qt.Key_F1 + 1);
        switch (key) {
        case Qt.Key_Ntilde: return "ntilde";
        case Qt.Key_Space: return "space";
        case Qt.Key_Return: case Qt.Key_Enter: return "Return";
        case Qt.Key_Tab: return "Tab";
        case Qt.Key_Backspace: return "BackSpace";
        case Qt.Key_Delete: return "Delete";
        case Qt.Key_Insert: return "Insert";
        case Qt.Key_Home: return "Home";
        case Qt.Key_End: return "End";
        case Qt.Key_PageUp: return "Prior";
        case Qt.Key_PageDown: return "Next";
        case Qt.Key_Left: return "Left";
        case Qt.Key_Right: return "Right";
        case Qt.Key_Up: return "Up";
        case Qt.Key_Down: return "Down";
        case Qt.Key_Print: return "Print";
        }
        return "";
    }

    function isModifier(key) {
        return [Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Control, Qt.Key_Alt,
                Qt.Key_AltGr, Qt.Key_Shift, Qt.Key_Hyper_L, Qt.Key_Hyper_R].indexOf(key) >= 0;
    }

    function startRecording() {
        if (root.phase !== "idle" || SendaHyprlandSettings.busy || SendaHyprlandSettings.recording) return;
        root.message = "";
        root.phase = "starting";
        SendaHyprlandSettings.recording = true;
        captureStart.running = true;
    }

    // Leaves the capture submap; keepState keeps a pending result on screen.
    function stopRecording(keepState) {
        if (root.phase === "recording" || root.phase === "starting") {
            captureStop.running = true;
        }
        timeout.stop();
        SendaHyprlandSettings.recording = false;
        if (!keepState) root.phase = "idle";
    }

    function finish(shortcut) {
        root.stopRecording(true);
        root.candidate = shortcut;
        root.phase = "checking";
        check.command = [SendaHyprlandSettings.binaryPath, "hyprland", "check", "--for", root.target, "--shortcut", shortcut];
        check.running = true;
    }

    function save(shortcut) {
        root.phase = "idle";
        root.conflicts = [];
        if (shortcut !== root.value) SendaHyprlandSettings.save(root.flag, shortcut);
    }

    Component.onDestruction: if (root.phase === "recording" || root.phase === "starting") captureStop.running = true

    RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Theme.spacing.sm

        // Shows the shortcut, or the prompt while recording. It takes the
        // keyboard focus during recording to receive the combination.
        Rectangle {
            id: shortcutDisplay
            Layout.preferredWidth: 150
            implicitHeight: displayText.implicitHeight + Theme.spacing.lg
            radius: Theme.rounding.small
            color: Theme.colors.background
            border.width: 1
            border.color: root.phase === "recording" || (activeFocus && root.phase === "idle") ? Theme.colors.primary
                : savedPulse.running ? Theme.colors.success
                : fieldMouse.containsMouse ? Theme.colors.primary : Theme.colors.surfaceVariant
            Behavior on border.color { ColorAnimation { duration: 150 } }
            opacity: root.enabled ? 1 : 0.4
            focus: root.phase === "recording"
            // The field itself is reachable with
            // Tab and starts recording with Enter or Space.
            activeFocusOnTab: root.enabled
            Accessible.role: Accessible.Button
            Accessible.name: "Atajo: " + root.pretty(root.value)

            Text {
                id: displayText
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10 + savedMark.width
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: root.phase === "recording" ? "Pulsa la combinación…"
                    : root.phase === "starting" ? "Preparando…"
                    : root.phase === "checking" ? "Comprobando…"
                    : root.pretty(root.phase === "confirm" ? root.candidate : root.value)
                color: root.phase === "recording" ? Theme.colors.overlay : Theme.colors.text
                font.family: Theme.font.base.family
                font.pixelSize: Theme.scaled(12)
            }

            // Clicking the field starts recording.
            MouseArea {
                id: fieldMouse
                anchors.fill: parent
                enabled: root.enabled && root.phase === "idle" && !SendaHyprlandSettings.recording
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.startRecording()
            }

            // Confirms a save without text: green border and a fading check.
            Text {
                id: savedMark
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf00c"
                color: Theme.colors.success
                font.family: Theme.iconFamily
                font.pixelSize: Theme.scaled(12)
                opacity: 0
                Accessible.ignored: true
            }
            SequentialAnimation {
                id: savedPulse
                NumberAnimation { target: savedMark; property: "opacity"; to: 1; duration: 120 }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: savedMark; property: "opacity"; to: 0; duration: 400 }
            }
            Connections {
                target: SendaHyprlandSettings
                function onSaved(flag) { if (flag === root.flag) savedPulse.restart(); }
            }

            Keys.onPressed: event => {
                event.accepted = true;
                if (root.phase === "idle" && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].indexOf(event.key) >= 0) {
                    root.startRecording();
                    return;
                }
                if (root.phase !== "recording") {
                    event.accepted = false;
                    return;
                }
                if (event.key === Qt.Key_Escape) {
                    root.stopRecording(false);
                    return;
                }
                if (event.isAutoRepeat || root.isModifier(event.key)) return;
                const key = root.keyName(event.key);
                if (!key) {
                    root.message = "Tecla no admitida; prueba con otra combinación.";
                    return;
                }
                const mods = [];
                if (event.modifiers & Qt.MetaModifier) mods.push("SUPER");
                if (event.modifiers & Qt.ControlModifier) mods.push("CTRL");
                if (event.modifiers & Qt.AltModifier) mods.push("ALT");
                if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT");
                root.message = "";
                root.finish(mods.concat([key]).join(" + "));
            }
            onActiveFocusChanged: if (!activeFocus && root.phase === "recording") root.stopRecording(false)
        }

        SettingsButton {
            visible: root.phase === "recording" || root.phase === "starting"
            label: "Cancelar"
            onClicked: root.stopRecording(false)
        }
        // Compact icon button so the row stays narrow.
        Controls.AbstractButton {
            id: resetButton
            visible: root.phase === "idle" && root.defaultValue !== "" && root.value !== root.defaultValue
            enabled: root.enabled && !SendaHyprlandSettings.recording
            implicitWidth: shortcutDisplay.implicitHeight
            implicitHeight: shortcutDisplay.implicitHeight
            opacity: enabled ? 1 : 0.4
            Accessible.name: "Restablecer"
            Accessible.description: "Volver a " + root.pretty(root.defaultValue)
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: "Restablecer: " + root.pretty(root.defaultValue)
            onClicked: root.save(root.defaultValue)
            contentItem: Text {
                text: "\uf0e2"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.colors.text
                font.family: Theme.iconFamily
                font.pixelSize: Theme.scaled(13)
            }
            background: Rectangle {
                radius: Theme.rounding.small
                color: resetButton.down || resetButton.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface
                border.width: 1
                border.color: resetButton.visualFocus ? Theme.colors.focus : Theme.colors.border
            }
        }
    }

    // Conflicts with other Hyprland binds need confirmation.
    ColumnLayout {
        visible: root.phase === "confirm"
        Layout.alignment: Qt.AlignRight
        spacing: Theme.spacing.xs
        Text {
            Layout.alignment: Qt.AlignRight
            text: "Ya lo usa: " + root.conflicts.join(", ")
            color: Theme.colors.warning
            font: Theme.font.caption
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            SettingsButton {
                label: "Guardar igualmente"
                onClicked: root.save(root.candidate)
            }
            SettingsButton {
                label: "Cancelar"
                onClicked: { root.phase = "idle"; root.conflicts = []; }
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignRight
        visible: root.message !== ""
        text: root.message
        color: Theme.colors.warning
        font: Theme.font.caption
    }

    // Safety net: never leave Hyprland in the capture submap for long.
    Timer {
        id: timeout
        interval: 10000
        onTriggered: {
            root.message = "No se ha pulsado ninguna combinación.";
            root.stopRecording(false);
        }
    }

    // Escape is bound in the capture submap, so Hyprland may leave it before
    // the key reaches Senda; follow the submap change.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap" && event.data === "" && root.phase === "recording") {
                timeout.stop();
                SendaHyprlandSettings.recording = false;
                root.phase = "idle";
            }
        }
    }

    Process {
        id: captureStart
        command: [SendaHyprlandSettings.binaryPath, "hyprland", "capture", "start"]
        stderr: StdioCollector { id: captureErrors }
        onExited: exitCode => {
            if (root.phase !== "starting") {
                // Cancelled while starting: make sure the submap is left.
                captureStop.running = true;
                return;
            }
            if (exitCode !== 0) {
                SendaHyprlandSettings.recording = false;
                root.phase = "idle";
                root.message = "No se pudo iniciar la grabación: " + (captureErrors.text.trim() || "error desconocido");
                return;
            }
            root.phase = "recording";
            shortcutDisplay.forceActiveFocus();
            timeout.restart();
        }
    }

    Process {
        id: captureStop
        command: [SendaHyprlandSettings.binaryPath, "hyprland", "capture", "stop"]
    }

    Process {
        id: check
        stdout: StdioCollector { id: checkOutput }
        stderr: StdioCollector { id: checkErrors }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.phase = "idle";
                root.message = "Atajo no válido: " + (checkErrors.text.trim() || "error desconocido");
                return;
            }
            let result;
            try {
                result = JSON.parse(checkOutput.text);
            } catch (error) {
                root.phase = "idle";
                root.message = "No se pudo comprobar el atajo.";
                return;
            }
            const own = result.conflicts.filter(c => c.startsWith("Senda:"));
            if (own.length > 0) {
                root.phase = "idle";
                root.message = "Ese atajo ya lo usa Senda (" + own.join(", ").replace(/Senda: /g, "") + ").";
                return;
            }
            root.candidate = result.shortcut;
            if (result.conflicts.length > 0) {
                root.conflicts = result.conflicts;
                root.phase = "confirm";
                return;
            }
            root.save(result.shortcut);
        }
    }
}
