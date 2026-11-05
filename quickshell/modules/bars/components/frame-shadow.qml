import QtQuick

import qs.common

// The part of the frame's inner shadow that falls inside this item. The bar
// and the frame strips each paint their own band, so the shadow needs no
// full-screen layer. Its outline joins the bar and frame with the same
// quadratic curves as BarCorner.
Canvas {
	id: root

	// Screen size and this item's top-left corner in screen coordinates.
	required property real screenWidth
	required property real screenHeight
	property real originX: 0
	property real originY: 0

	readonly property real frameSize: Theme.frameSize
	readonly property real barSize: Theme.barSize
	readonly property real cornerRadius: Theme.barBorderRadius

	onWidthChanged: requestPaint()
	onHeightChanged: requestPaint()
	onScreenWidthChanged: requestPaint()
	onScreenHeightChanged: requestPaint()
	onOriginXChanged: requestPaint()
	onOriginYChanged: requestPaint()
	onFrameSizeChanged: requestPaint()
	onBarSizeChanged: requestPaint()
	onCornerRadiusChanged: requestPaint()

	onPaint: {
		const ctx = getContext("2d");
		ctx.reset();
		if (width <= 0 || height <= 0)
			return;
		ctx.translate(-originX, -originY);
		const left = frameSize;
		const top = barSize;
		const right = screenWidth - frameSize;
		const bottom = screenHeight - frameSize;
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
		// shadowBlur blurs the whole image on the GUI thread. Concentric strokes
		// rebuild its falloff: a 2 px line blurred with sigma 6.5; 0.25 matches
		// the old render's intensity.
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
		for (let d = Theme.frameShadowSize; d >= 2; d -= 2) {
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
