import QtQuick
import QtQuick.Shapes
import qs.common

Item {
	id: root

	default property alias content: contentArea.data

	property bool expanded: false
	property real expandedHeight: Theme.barSize
	property color backgroundColor: Theme.colors.background
	property real cornerRadius: Theme.barBorderRadius
	property real contentFadeDistance: 50
	property real contentHideThreshold: 3
	property bool autoHideOnPointerExit: true
	property int autoHideDelay: 1000
	property bool autoHidePaused: false
	property bool pointerEntered: false

	signal closeRequested()

	readonly property real collapseLift: expanded ? 0 : Math.max(0, contentHideThreshold - height)
	readonly property real curveWidth: Math.max(0, Math.min(cornerRadius, width / 4))
	readonly property real curveHeight: {
		const halfHeight = Math.max(0, height / 2);
		const blendRange = curveWidth / 4;
		if (blendRange === 0) return 0;

		// Start blending just before the upper and lower curves would touch.
		// A smooth minimum keeps their tangents aligned without overlapping.
		const blend = Math.max(0, 1 - Math.abs(curveWidth - halfHeight) / blendRange);
		return Math.min(curveWidth, halfHeight) - blendRange * blend * blend / 4;
	}

	height: expanded ? expandedHeight : 0
	visible: expanded || height > 0.01
	clip: true

	Behavior on height {
		id: heightBehavior
		NumberAnimation {
			duration: heightBehavior.targetValue > 0 ? 310 : 310
			easing.type: Easing.OutCubic
		}
	}

	onExpandedChanged: {
		if (!expanded) {
			autoHideTimer.stop();
			pointerEntered = false;
		}
	}

	onAutoHidePausedChanged: {
		if (autoHidePaused) {
			autoHideTimer.stop();
		} else if (expanded && pointerEntered && !pointerHover.hovered && autoHideOnPointerExit) {
			autoHideTimer.restart();
		}
	}

	HoverHandler {
		id: pointerHover

		onHoveredChanged: {
			if (hovered) {
				root.pointerEntered = true;
				autoHideTimer.stop();
			} else if (root.expanded && root.pointerEntered && root.autoHideOnPointerExit && !root.autoHidePaused) {
				autoHideTimer.restart();
			}
		}
	}

	Timer {
		id: autoHideTimer
		interval: Math.max(0, root.autoHideDelay)
		repeat: false
		onTriggered: {
			if (root.expanded && root.pointerEntered && !root.autoHidePaused && !pointerHover.hovered)
				root.closeRequested();
		}
	}

	Shape {
		anchors.fill: parent
		preferredRendererType: Shape.CurveRenderer

		ShapePath {
			strokeColor: "transparent"
			strokeWidth: -1
			fillColor: root.backgroundColor
			startX: 0
			startY: 0

			PathLine { x: root.width; y: 0 }
			PathQuad {
				x: root.width - root.curveWidth
				y: root.curveHeight
				controlX: root.width - root.curveWidth
				controlY: 0
			}
			PathLine {
				x: root.width - root.curveWidth
				y: root.height - root.curveHeight
			}
			PathQuad {
				x: root.width - 2 * root.curveWidth
				y: root.height
				controlX: root.width - root.curveWidth
				controlY: root.height
			}
			PathLine { x: 2 * root.curveWidth; y: root.height }
			PathQuad {
				x: root.curveWidth
				y: root.height - root.curveHeight
				controlX: root.curveWidth
				controlY: root.height
			}
			PathLine { x: root.curveWidth; y: root.curveHeight }
			PathQuad {
				x: 0
				y: 0
				controlX: root.curveWidth
				controlY: 0
			}
		}
	}

	Item {
		id: contentArea
		x: root.curveWidth
		width: Math.max(0, root.width - 2 * root.curveWidth)
		height: root.height
		opacity: root.contentFadeDistance <= 0
		? 1
		: Math.max(0, Math.min(1, root.height / Math.min(root.contentFadeDistance, Math.max(1, root.expandedHeight))))
	}
}
