import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services

WlSessionLockSurface {
    id: surface
    color: "transparent"
    property date now: new Date()
    // The surface that receives keys owns the password field, even when
    // Hyprland's focused monitor is stale, for example after opening the lid.
    property bool typedHere: false
    readonly property bool focused: typedHere || !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screen?.name
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() { surface.typedHere = false; }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: surface.now = new Date() }
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        // Any key typed while the field has no focus gives it back the focus
        // and is not lost: printable text goes into the field.
        Keys.onPressed: event => {
            surface.typedHere = true;
            if (!password.enabled) return;
            password.forceActiveFocus();
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                password.accepted();
            } else if (event.key === Qt.Key_Backspace) {
                password.remove(password.length - 1, password.length);
            } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
                password.insert(password.length, event.text);
            }
            event.accepted = true;
        }
        Rectangle { anchors.fill: parent; color: "#b0000000" }
        Item {
            anchors.centerIn: parent
            width: 900; height: 640; scale: Math.min(1, parent.width / width, parent.height / height)
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 0; text: Qt.formatTime(surface.now, "HH:mm"); color: "#ccfafafa"; font.family: "Google Sans Flex"; font.bold: true; font.pointSize: 220 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 145; text: Qt.formatDate(surface.now, "dddd"); color: "#ff832c"; font.family: "Betterlett"; font.bold: true; font.pointSize: 60 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 300; text: "───"; color: Theme.colors.white; font.family: "Google Sans Flex"; font.pointSize: 60 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 400; text: surface.now.toLocaleDateString(Qt.locale(), "dd MMMM yyyy"); color: Theme.colors.white; font.family: "Google Sans Flex"; font.bold: true; font.pointSize: 34 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 490; text: "¡Hola, " + Quickshell.env("USER") + "!"; color: Theme.colors.white; font.family: "Google Sans Flex"; font.pointSize: 22 }
            TextField {
                id: password
                anchors.horizontalCenter: parent.horizontalCenter; y: 560; width: 200; height: 35
                visible: surface.focused; focus: surface.focused; enabled: !LockService.authenticating
                echoMode: TextInput.Password; horizontalAlignment: TextInput.AlignHCenter; color: Theme.colors.white
                cursorDelegate: Item { visible: false }
                transform: Translate { id: errorOffset }
                background: Rectangle {
                    radius: 18; color: "#33fafafa"; border.width: 2
                    border.color: LockService.errorMessage ? Theme.colors.error : "#4dfafafa"
                    Behavior on border.color { ColorAnimation { duration: Theme.motion.normal } }
                }
                Connections {
                    target: LockService
                    function onErrorMessageChanged() {
                        if (LockService.errorMessage && surface.focused) errorShake.restart();
                    }
                }
                SequentialAnimation {
                    id: errorShake
                    NumberAnimation { target: errorOffset; property: "x"; to: -9; duration: 50 }
                    NumberAnimation { target: errorOffset; property: "x"; to: 9; duration: 90 }
                    NumberAnimation { target: errorOffset; property: "x"; to: -5; duration: 70 }
                    NumberAnimation { target: errorOffset; property: "x"; to: 5; duration: 60 }
                    NumberAnimation { target: errorOffset; property: "x"; to: 0; duration: 50 }
                }
                onAccepted: { const value = text; clear(); LockService.authenticate(value); }
                // Disabling the field during authentication drops its focus;
                // take it back as soon as it can be typed into again.
                onEnabledChanged: if (enabled && visible) forceActiveFocus()
                onVisibleChanged: if (enabled && visible) forceActiveFocus()
                onActiveFocusChanged: if (!activeFocus) keyCatcher.forceActiveFocus()
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 605; text: LockService.errorMessage; color: Theme.colors.error; visible: surface.focused }
        }
    }
}
