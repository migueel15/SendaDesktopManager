import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.common
import qs.services

Item {
	id: root

	default property alias content: contentArea.data

	property bool expanded: false
	property real expandedHeight: Theme.barSize
	property color backgroundColor: Theme.colors.background
	readonly property int shadowSpace: 20
	property real cornerRadius: Theme.barBorderRadius
	property real contentFadeDistance: 50
	property real contentHideThreshold: 3
	property bool autoHideOnPointerExit: true
	property int autoHideDelay: 1000
	property bool autoHideStartsOnExpand: false
	property bool autoHidePaused: false
	property bool autoHideArmed: false
	property string conflictGroup: ""
	// Duration used when expandedHeight changes while open. Content that animates
	// its own height should use 0, so the background follows it without lagging.
	property int resizeDuration: 310
	// True from an open or close until its height animation ends.
	property bool toggling: false

	signal closeRequested()

	Component.onCompleted: BarExtensionManager.registerExtension(root)
	Component.onDestruction: BarExtensionManager.unregisterExtension(root)

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
	clip: false

	Behavior on height {
		id: heightBehavior
		NumberAnimation {
			duration: root.toggling ? 310 : root.resizeDuration
			easing.type: Easing.OutCubic
			onRunningChanged: {
				if (!running) root.toggling = false;
			}
		}
	}

	onExpandedChanged: {
		toggling = true;
		if (expanded) BarExtensionManager.activate(root);
		if (!expanded) {
			autoHideTimer.stop();
			autoHideArmed = false;
		} else if (autoHideStartsOnExpand) {
			autoHideArmed = true;
			if (autoHideOnPointerExit && !autoHidePaused && !pointerHover.hovered)
				autoHideTimer.restart();
		}
	}

	onConflictGroupChanged: {
		if (expanded) BarExtensionManager.activate(root);
	}

	onAutoHidePausedChanged: {
		if (autoHidePaused) {
			autoHideTimer.stop();
		} else if (expanded && autoHideArmed && !pointerHover.hovered && autoHideOnPointerExit) {
			autoHideTimer.restart();
		}
	}

	HoverHandler {
		id: pointerHover

		onHoveredChanged: {
			if (hovered) {
				root.autoHideArmed = true;
				autoHideTimer.stop();
			} else if (root.expanded && root.autoHideArmed && root.autoHideOnPointerExit && !root.autoHidePaused) {
				autoHideTimer.restart();
			}
		}
	}

	Timer {
		id: autoHideTimer
		interval: Math.max(0, root.autoHideDelay)
		repeat: false
		onTriggered: {
			if (root.expanded && root.autoHideArmed && !root.autoHidePaused && !pointerHover.hovered)
				root.closeRequested();
		}
	}

	MultiEffect {
		anchors.fill: backgroundShape
		source: backgroundShape
		visible: root.height > root.contentHideThreshold
		shadowEnabled: true
		shadowColor: "#b0000000"
		blurMax: 16
		shadowBlur: 0.8
		shadowVerticalOffset: 4
	}

	Shape {
		id: backgroundShape
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
		clip: true
		x: root.curveWidth
		width: Math.max(0, root.width - 2 * root.curveWidth)
		height: root.height
		opacity: root.contentFadeDistance <= 0
		? 1
		: Math.max(0, Math.min(1, root.height / Math.min(root.contentFadeDistance, Math.max(1, root.expandedHeight))))
	}
}
