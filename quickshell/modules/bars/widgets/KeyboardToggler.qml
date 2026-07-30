import Quickshell
import QtQuick

import Quickshell.Io

import qs.common

Rectangle {
		id: root
		property bool keyboardEnabled : true

		height: parent.height
		width: textIcon.implicitWidth
		color: "transparent"

	Text{
		id: textIcon
    anchors.centerIn: parent

		text : root.keyboardEnabled ? "󰌌": "󰌐"

		font : Theme.font.base
		// color: keyboardEnabled ? Theme.colors.text : Theme.colors.surfaceVariant
		color: Theme.colors.text


	}

	MouseArea {
		anchors.fill : parent
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
