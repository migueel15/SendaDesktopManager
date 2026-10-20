import Quickshell
import QtQuick

import Quickshell.Io

import qs.common

Rectangle {
		id: root
		property bool keyboardEnabled : true

		height: parent.height
		width: textIcon.implicitWidth + 16
		implicitWidth: width
		color: "transparent"


    // Same hover pill as the control panel button.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height * 0.8
        radius: Theme.rounding.normal
        color: keyboardMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

	Text{
		id: textIcon
    anchors.centerIn: parent

		text : root.keyboardEnabled ? "󰌌": "󰌐"

		font : Theme.font.base
		// color: keyboardEnabled ? Theme.colors.text : Theme.colors.surfaceVariant
		color: Theme.colors.text


	}

	MouseArea {
		id: keyboardMouse
		anchors.fill : parent
		hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

		onClicked: {
			if (!toggleKeyboardProc.running){
				toggleKeyboardProc.running = true;
			}
		}
	}

	Process {
		id : toggleKeyboardProc
		running: false
		command: ["hyprctl", "eval", "Senda.keyboard.toggle()"]
		onExited: function(exitCode,exitStatus){
			if (exitCode === 0){
				root.keyboardEnabled = !root.keyboardEnabled
			}
		}
	}
}
