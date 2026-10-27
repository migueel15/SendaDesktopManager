pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
	id: root

	property string currentTheme: "zenda-ice"

	// Spanish names for days and months, whatever the system locale is.
	readonly property var locale: Qt.locale("es_ES")

	// Interface text scale. 1.0 is the default size; the settings panel changes
	// it through SENDA_UI_FONT_SCALE.
	property real fontScale: 1.0

	// Scales a font size in pixels by the interface scale.
	function scaled(size) {
		return Math.round(size * root.fontScale);
	}

	// Takes the percentage from the settings file. Empty or invalid values fall
	// back to 100%, and the range matches the one the CLI accepts.
	function setFontScale(percent) {
		const value = parseInt(percent, 10);
		const valid = !isNaN(value) && value >= 80 && value <= 150;
		root.fontScale = valid ? value / 100 : 1.0;
	}

	function applyColors(map) {
		const keys = ["base", "background", "surface", "border", "surfaceVariant",
			"surfaceRaised", "surfaceRaisedBorder", "overlay", "textMuted", "white",
			"primary", "secondary", "accent", "accentDeep", "selection", "focus",
			"success", "warning", "error", "info", "text"];
		for (const key of keys) {
			if (map && Object.prototype.hasOwnProperty.call(map, key))
				root.colors[key] = map[key];
		}
	}

	readonly property Colors colors: Colors {}
	readonly property Rounding rounding: Rounding {}
	readonly property Spacing spacing: Spacing {}
	readonly property Motion motion: Motion {}
	readonly property Fonts font: Fonts {}
	readonly property Workspaces workspaces: Workspaces {}
	readonly property Notifications notifications: Notifications {}

	// Senda palette. Neutrals: Noche, Grafito, Pizarra, Humo, Bruma.
	// Accent: Abismo, Cobalto, Hielo, Escarcha.
	component Colors: QtObject {
		// Desktop background, darker than bars and panels.
		property color base: "#0A0E16"
		// Bars and panels (Grafito).
		property color background: "#11161F"
		// Cards inside panels.
		property color surface: "#141A26"
		property color border: "#222B3A"
		// Hover fills and inactive borders (Pizarra).
		property color surfaceVariant: "#263042"
		// Selectors that unfold under a card, a step lighter than surface.
		property color surfaceRaised: "#1A2130"
		property color surfaceRaisedBorder: "#3E4A60"
		// Secondary text (Humo).
		property color overlay: "#8695AD"
		property color textMuted: "#C6CFDD"
		property color white: "#F2F7FF"
		// Hielo.
		property color primary: "#7AA7FF"
		// Escarcha.
		property color secondary: "#CFE3FF"
		// Cobalto.
		property color accent: "#3D6FD1"
		property color accentDeep: "#0F1E38"
		// Selected or active items: deep fill with a Hielo border and text.
		property color selection: "#1F3A66"
		property color focus: "#7AA7FF"
		property color success: "#6FD3A0"
		property color warning: "#F2C46D"
		property color error: "#F27A8A"
		property color info: "#A79CFF"
		// Bruma.
		property color text: "#E8EEF7"
	}

	component Rounding: QtObject {
		readonly property int small: 6
		readonly property int normal: 10
		readonly property int large: 16
		readonly property int full: 1000
	}

	// Spacing scale for gaps, margins, and padding. Avoid values off the scale.
	component Spacing: QtObject {
		readonly property int xxs: 2
		readonly property int xs: 4
		readonly property int sm: 8
		readonly property int md: 12
		readonly property int lg: 16
		readonly property int xl: 24
	}

	// Durations in milliseconds. fast: hover and colors; normal: small moves and
	// fades; slow: panels unfolding. Easing is OutCubic everywhere.
	component Motion: QtObject {
		readonly property int fast: 120
		readonly property int normal: 180
		readonly property int slow: 310
		readonly property int easing: Easing.OutCubic
	}

	// Inter for text. Icons are Nerd Font glyphs: plain icons use Symbols
	// Nerd Font, and mixed strings fall back to it through fontconfig.
	readonly property string textFamily: "Inter"
	readonly property string iconFamily: "Symbols Nerd Font"

	component Fonts: QtObject {
		property font base: Qt.font({
				family: root.textFamily,
				pixelSize: root.scaled(17),
				weight: Font.Normal
		})
		property font title: Qt.font({
				family: root.textFamily,
				pixelSize: root.scaled(16),
				weight: Font.DemiBold
		})
		// Big numbers such as the dashboard clock.
		property font display: Qt.font({
				family: root.textFamily,
				pixelSize: root.scaled(36),
				weight: Font.Light
		})
		// Card and section headings.
		property font heading: Qt.font({
				family: root.textFamily,
				pixelSize: root.scaled(14),
				weight: Font.DemiBold
		})
		// Default text inside panels.
		property font body: Qt.font({
				family: root.textFamily,
				pixelSize: root.scaled(13),
				weight: Font.Normal
		})
		// Secondary details: times, counters, hints.
		property font caption: Qt.font({
				family: root.textFamily,
				pixelSize: root.scaled(11),
				weight: Font.Normal
		})
		// Small uppercase labels over groups.
		property font label: Qt.font({
				family: root.textFamily,
				pixelSize: root.scaled(10),
				weight: Font.DemiBold,
				capitalization: Font.AllUppercase,
				letterSpacing: 0.6
		})
		property font overlay: Qt.font({
				family: root.textFamily,
				pixelSize: root.scaled(13),
				weight: Font.Normal
		})
		property font icon: Qt.font({
				family: root.iconFamily,
				pixelSize: root.scaled(13),
				weight: Font.Normal
		})
	}

	property int barSize: 40
	// Square size of icon-only buttons on the bar.
	readonly property int barButtonSize: Math.round(barSize * 0.8)
	// Width of the frame on the left, right, and bottom edges of each screen.
	property int frameSize: 6
	property int barBorderRadius: Theme.rounding.normal

	component Workspaces: QtObject {
		property string icon: ""
		property font font: Theme.font.icon
		property int spacing: 8
		property color activeWorkspaceColor: root.colors.white
		property color notFocusedWorkspaceColor: root.colors.primary
		property color emptyWorkspaceColor: root.colors.overlay
	}

	component Notifications: QtObject {
		property QtObject icon: QtObject {
			property string notification: "󱅫"
			property string none: "󰂚"
			property string dnd_none: "󰂛"
		}
	}
}
