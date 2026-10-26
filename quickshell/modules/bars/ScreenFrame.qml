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

		// A transparent, input-free layer draws the shadow into the desktop.
		// Its outline joins the bar and frame with the same quadratic curves as BarCorner.
		PanelWindow {
			screen: frame.modelData
			anchors { top: true; bottom: true; left: true; right: true }
			exclusionMode: ExclusionMode.Ignore
			focusable: false
			aboveWindows: true
			WlrLayershell.namespace: "Senda:FrameShadow"
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
			mask: Region {}
			color: "transparent"

			Canvas {
				id: shadowCanvas
				anchors.fill: parent
				readonly property real frameSize: Theme.frameSize
				readonly property real barSize: Theme.barSize
				readonly property real cornerRadius: Theme.barBorderRadius
				onWidthChanged: requestPaint()
				onHeightChanged: requestPaint()
				onFrameSizeChanged: requestPaint()
				onBarSizeChanged: requestPaint()
				onCornerRadiusChanged: requestPaint()
				onPaint: {
					const ctx = getContext("2d");
					ctx.reset();
					const left = frameSize;
					const top = barSize;
					const right = width - frameSize;
					const bottom = height - frameSize;
					const radius = Math.max(0, Math.min(cornerRadius, (right - left) / 2, (bottom - top) / 2));
					if (right <= left || bottom <= top) return;
					ctx.beginPath();
					ctx.moveTo(left + radius, top);
					ctx.lineTo(right - radius, top);
					ctx.quadraticCurveTo(right, top, right, top + radius);
					ctx.lineTo(right, bottom - radius);
					ctx.quadraticCurveTo(right, bottom, right - radius, bottom);
					ctx.lineTo(left + radius, bottom);
					ctx.quadraticCurveTo(left, bottom, left, bottom - radius);
					ctx.lineTo(left, top + radius);
					ctx.quadraticCurveTo(left, top, left + radius, top);
					ctx.closePath();
					ctx.clip();
					ctx.strokeStyle = "rgba(0, 0, 0, 0.35)";
					ctx.lineWidth = 2;
					ctx.shadowColor = "rgba(0, 0, 0, 0.65)";
					ctx.shadowBlur = 12;
					ctx.stroke();
				}
			}
		}
	}
}
