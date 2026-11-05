import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.common
import qs.services

Item {
	id: root

	default property alias content: contentArea.data

	property bool expanded: false
	// Edge the extension grows out of: "top" (the bar) or "bottom" (the
	// bottom screen frame). Bottom mirrors the shape; place the item so its
	// bottom stays on the frame, e.g. y: parent.height - height.
	property string edge: "top"
	readonly property bool fromBottom: edge === "bottom"
	property real expandedHeight: Theme.barSize
	property color backgroundColor: Theme.colors.background
	readonly property int shadowSpace: 20
	// Style B: the same large radius as cards, so extensions read as cards
	// growing out of the bar.
	property real cornerRadius: Theme.card.radius
	// False when nothing is drawn above the shape, as when a fullscreen window
	// covers the bar: the top corners round inwards instead of joining the bar.
	property bool attachedToBar: true
	// Shape of each corner: "bar" joins the bar above with a concave curve,
	// "round" is a convex corner, "square" is a right angle and "wall" joins
	// a screen edge on that side with a concave curve (bottom right corner only).
	property string topLeftCorner: "bar"
	property string topRightCorner: "bar"
	property string bottomLeftCorner: "round"
	property string bottomRightCorner: "round"
	// Horizontal space a side takes for its curves; it needs no space when
	// its corners are square or join a wall. Independent of the width, so
	// parents can size the extension from it.
	readonly property real leftSpace: ["bar", "round"].indexOf(topLeftCorner) !== -1
		|| ["bar", "round"].indexOf(bottomLeftCorner) !== -1 ? cornerRadius : 0
	readonly property real rightSpace: ["bar", "round"].indexOf(topRightCorner) !== -1
		|| ["bar", "round"].indexOf(bottomRightCorner) !== -1 ? cornerRadius : 0
	readonly property bool bottomRightIsWall: bottomRightCorner === "wall"
	readonly property real leftEdge: leftSpace > 0 ? curveWidth : 0
	readonly property real rightEdge: width - (rightSpace > 0 ? curveWidth : 0)
	// Bottom of the body: a wall curve takes the last bit of the height.
	readonly property real bodyBottom: bottomRightIsWall ? height - curveHeight : height
	// Where each corner meets the top edge (x), the side (y) and the bottom.
	readonly property bool topLeftFlat: topLeftCorner === "square" || topLeftCorner === "wall"
	readonly property bool topRightFlat: topRightCorner === "square" || topRightCorner === "wall"
	readonly property real topLeftX: topLeftFlat ? leftEdge
		: topLeftCorner === "bar" && attachedToBar ? 0 : leftEdge + curveHeight
	readonly property real topLeftY: topLeftFlat ? 0 : curveHeight
	readonly property real topRightX: topRightFlat ? rightEdge
		: topRightCorner === "bar" && attachedToBar ? width : rightEdge - curveHeight
	readonly property real topRightY: topRightFlat ? 0 : curveHeight
	readonly property real bottomLeftX: bottomLeftCorner === "round" ? curveWidth : 0
	readonly property real bottomLeftY: bottomLeftCorner === "round" ? curveHeight : 0
	readonly property real bottomRightX: bottomRightCorner === "round" ? curveWidth : 0
	readonly property real bottomRightY: bottomRightCorner === "round" ? curveHeight : 0
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
	property int resizeDuration: Theme.motion.slow + 60
	// True from an open or close until its height animation ends.
	property bool toggling: false
	property bool initialized: false

	signal closeRequested()

	function initialize() {
		if (expanded) {
			toggling = true;
			BarExtensionManager.activate(root);
		}
		initialized = true;
	}

	Component.onCompleted: {
		BarExtensionManager.registerExtension(root);
		Qt.callLater(root.initialize);
	}
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

	height: initialized && expanded ? expandedHeight : 0
	visible: expanded || height > 0.01
	clip: false

	Behavior on height {
		id: heightBehavior
		NumberAnimation {
			duration: root.toggling ? Theme.motion.slow + 60 : root.resizeDuration
			easing.type: Easing.OutQuint
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

	Loader {
		anchors.fill: backgroundShape
		transform: Scale { origin.y: root.height / 2; yScale: root.fromBottom ? -1 : 1 }
		active: root.height > root.contentHideThreshold
		sourceComponent: Component {
			MultiEffect {
				anchors.fill: parent
				source: backgroundShape
				visible: true
				shadowEnabled: true
				shadowColor: "#90000000"
				blurMax: 24
				shadowBlur: 1.0
				shadowVerticalOffset: root.fromBottom ? -4 : 4
			}
		}
	}

	Shape {
		id: backgroundShape
		anchors.fill: parent
		transform: Scale { origin.y: root.height / 2; yScale: root.fromBottom ? -1 : 1 }
		preferredRendererType: Shape.CurveRenderer

		ShapePath {
			strokeColor: "transparent"
			strokeWidth: -1
			fillColor: root.backgroundColor
			startX: root.topLeftX
			startY: 0

			PathLine { x: root.topRightX; y: 0 }
			PathQuad {
				x: root.rightEdge
				y: root.topRightY
				controlX: root.rightEdge
				controlY: 0
			}
			PathLine {
				x: root.rightEdge
				y: root.bottomRightIsWall ? root.height : root.bodyBottom - root.bottomRightY
			}
			PathQuad {
				x: root.bottomRightIsWall ? root.rightEdge - root.curveWidth : root.rightEdge - root.bottomRightX
				y: root.bottomRightIsWall ? root.bodyBottom : root.bodyBottom
				controlX: root.rightEdge
				controlY: root.bodyBottom
			}
			PathLine { x: root.leftEdge + root.bottomLeftX; y: root.bodyBottom }
			PathQuad {
				x: root.leftEdge
				y: root.bodyBottom - root.bottomLeftY
				controlX: root.leftEdge
				controlY: root.bodyBottom
			}
			PathLine { x: root.leftEdge; y: root.topLeftY }
			PathQuad {
				x: root.topLeftX
				y: 0
				controlX: root.leftEdge
				controlY: 0
			}
		}
	}

	Item {
		id: contentArea
		clip: true
		x: root.leftEdge
		width: Math.max(0, root.rightEdge - root.leftEdge)
		height: root.bodyBottom
		opacity: root.contentFadeDistance <= 0
		? 1
		: Math.max(0, Math.min(1, root.height / Math.min(root.contentFadeDistance, Math.max(1, root.expandedHeight))))
	}
}
