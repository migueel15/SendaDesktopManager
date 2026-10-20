//@ pragma UseQApplication
//@ pragma RespectSystemStyle
//@ pragma DefaultEnv QT_QPA_PLATFORMTHEME=qt6ct
import Quickshell
import QtQuick
import QtQuick.Controls.Material

import qs.modules.bars
import qs.modules.bars.components
import qs.common.components
import qs.modules.panels

import Quickshell.Wayland

import qs.modules.wallpaper

ShellRoot {
	id: root

	Material.theme: Material.Dark
	Material.accent: Material.Purple

	TopBar {
		id: topBar
		panelController: panelCtrl
	}

	// The frame goes before the corners so they are placed inside it.
	ScreenFrame {}

	TopRightCorner {}
	TopLeftCorner {}
	BottomLeftCorner {}
	BottomRightCorner {}

	VolumeOSD {}

	Variants {
		id: panelCtrl
		model: Quickshell.screens

		OverlayLayer {}
	}

	WallpaperLayer {}

	Loader {
		active: true
		source: Qt.resolvedUrl("modules/panels/notifications/notification-popup.qml")
	}

	DebugLayer {
	}
}
