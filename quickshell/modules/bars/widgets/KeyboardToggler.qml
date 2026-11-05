import QtQuick

import qs.common
import qs.common.components.icons
import qs.common.components.controls
import qs.services

Rectangle {
		id: root

		height: parent.height
		width: Theme.barButtonSize
		implicitWidth: width
		color: "transparent"


    // Same hover pill as the control panel button.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Theme.barButtonSize
        radius: Theme.rounding.normal
        color: "transparent"
        ZendaStateLayer { hovered: keyboardMouse.containsMouse; pressed: keyboardMouse.pressed }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

	ZendaIcon {
		id: textIcon
    anchors.centerIn: parent

		text : ZendaManager.keyboardEnabled ? "󰌌": "󰌐"

		color: Theme.colors.text


	}

	MouseArea {
		id: keyboardMouse
		anchors.fill : parent
		hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

		onClicked: ZendaManager.toggleKeyboard()
	}
}
