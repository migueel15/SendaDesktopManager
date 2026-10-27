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
			exclusionMode: ExclusionMode.Normal
			exclusiveZone: 0
			margins { top: -Theme.barSize; left: -Theme.frameSize; right: -Theme.frameSize; bottom: -Theme.frameSize }
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
					// shadowBlur blurs a full-screen image on the GUI thread (~1.5 s per
					// monitor at startup). Concentric strokes rebuild its falloff: a 2 px
					// line blurred with sigma 6.5; 0.25 matches the old render's intensity.
					const sigma = 6.5;
					const erf = x => {
						const t = 1 / (1 + 0.3275911 * Math.abs(x));
						const y = 1 - t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429)))) * Math.exp(-x * x);
						return x < 0 ? -y : y;
					};
					const shadow = x => 0.25 * 0.5 * (erf((x + 1) / (sigma * Math.SQRT2)) - erf((x - 1) / (sigma * Math.SQRT2)));
					// Paint from the widest band inwards; each stroke adds just enough
					// alpha over the ones below to reach the target at its band.
					let below = 0;
					for (let d = 24; d >= 2; d -= 2) {
						const target = shadow(d - 1);
						const alpha = below >= target ? 0 : 1 - (1 - target) / (1 - below);
						below = target;
						if (alpha <= 0) continue;
						ctx.strokeStyle = Qt.rgba(0, 0, 0, alpha);
						ctx.lineWidth = d * 2;
						ctx.stroke();
					}
					ctx.strokeStyle = "rgba(0, 0, 0, 0.35)";
					ctx.lineWidth = 2;
					ctx.stroke();
				}
			}
		}
	}
}
