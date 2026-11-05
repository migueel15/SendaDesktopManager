import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.common
import qs.common.components
import qs.modules.bars.components

// Frame in the bar color around the left, right, and bottom edges of every
// screen. Each strip reserves only the frame width and reaches further into
// the desktop to paint its band of the frame shadow; the bottom strip also
// holds the lower edge corners. Only the frame itself takes input.
Variants {
	model: Quickshell.screens

	delegate: Scope {
		id: frame

		required property var modelData
		readonly property int reach: Theme.frameShadowReach
		readonly property real screenWidth: modelData.width
		readonly property real screenHeight: modelData.height

		component Strip: PanelWindow {
			screen: frame.modelData
			color: "transparent"
			focusable: false
			aboveWindows: true
			exclusionMode: ExclusionMode.Normal
			exclusiveZone: Theme.frameSize
			WlrLayershell.namespace: "Zenda:ScreenFrame"
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
		}

		// Placed below the top bar, from its bottom edge to the screen bottom.
		Strip {
			anchors {
				left: true
				top: true
				bottom: true
			}
			implicitWidth: Theme.frameSize + frame.reach
			mask: Region { item: leftFrame }

			Rectangle {
				id: leftFrame
				width: Theme.frameSize
				height: parent.height
				color: Theme.colors.background
			}

			// The top band belongs to the bar and the bottom band to the bottom strip.
			FrameShadow {
				x: Theme.frameSize
				y: frame.reach
				width: frame.reach
				height: Math.max(0, parent.height - Theme.frameSize - 2 * frame.reach)
				screenWidth: frame.screenWidth
				screenHeight: frame.screenHeight
				originX: Theme.frameSize
				originY: Theme.barSize + frame.reach
			}
		}

		Strip {
			anchors {
				right: true
				top: true
				bottom: true
			}
			implicitWidth: Theme.frameSize + frame.reach
			mask: Region { item: rightFrame }

			Rectangle {
				id: rightFrame
				x: parent.width - width
				width: Theme.frameSize
				height: parent.height
				color: Theme.colors.background
			}

			FrameShadow {
				y: frame.reach
				width: frame.reach
				height: Math.max(0, parent.height - Theme.frameSize - 2 * frame.reach)
				screenWidth: frame.screenWidth
				screenHeight: frame.screenHeight
				originX: frame.screenWidth - Theme.frameSize - frame.reach
				originY: Theme.barSize + frame.reach
			}
		}

		// Placed between the side strips.
		Strip {
			anchors {
				left: true
				right: true
				bottom: true
			}
			implicitHeight: Theme.frameSize + frame.reach
			mask: Region { item: bottomFrame }

			Rectangle {
				id: bottomFrame
				y: parent.height - height
				width: parent.width
				height: Theme.frameSize
				color: Theme.colors.background
			}

			FrameShadow {
				width: parent.width
				height: frame.reach
				screenWidth: frame.screenWidth
				screenHeight: frame.screenHeight
				originX: Theme.frameSize
				originY: frame.screenHeight - Theme.frameSize - frame.reach
			}

			BarCorner {
				y: parent.height - Theme.frameSize - height
				position: "bottom-left"
			}

			BarCorner {
				x: parent.width - width
				y: parent.height - Theme.frameSize - height
				position: "bottom-right"
			}
		}
	}
}
