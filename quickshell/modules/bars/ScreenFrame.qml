import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.common

// Frame in the bar color around the left, right, and bottom edges of every
// screen. Each strip reserves its space, so windows and the edge corners sit
// inside it and the corners curve from the frame into the desktop.
Variants {
	model: Quickshell.screens

	delegate: Scope {
		id: frame

		required property var modelData

		component Strip: PanelWindow {
			screen: frame.modelData
			color: Theme.colors.background
			focusable: false
			aboveWindows: true
			exclusionMode: ExclusionMode.Normal
			exclusiveZone: Theme.frameSize
			WlrLayershell.namespace: "Senda:ScreenFrame"
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
		}

		Strip {
			anchors {
				left: true
				top: true
				bottom: true
			}
			implicitWidth: Theme.frameSize
		}

		Strip {
			anchors {
				right: true
				top: true
				bottom: true
			}
			implicitWidth: Theme.frameSize
		}

		Strip {
			anchors {
				left: true
				right: true
				bottom: true
			}
			implicitHeight: Theme.frameSize
		}
	}
}
