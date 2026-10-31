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
import qs.modules.panels.Settings

import Quickshell.Wayland

import qs.modules.themes
import qs.modules.wallpaper
import qs.services
import qs.modules.stt
import qs.modules.screenshot
import qs.modules.lock
import qs.common

ShellRoot {
	id: root

	// IPC endpoints must exist even before their first view is constructed.
	readonly property var launcherService: LauncherService
	Component.onCompleted: SendaTheme.start()

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
	BrightnessOSD {}
	MediaKeys {}

	SttDock {}
	LockScreen {}
	ScreenshotLayer {}
	DisplayConfirmDialog {}
	LazyLoader {
		active: Bluetooth.pairingPrompt !== null
		BluetoothPairDialog {}
	}
	SettingsWindow {}

	Variants {
		id: panelCtrl
		model: Quickshell.screens

		OverlayLayer {}
	}

	WallpaperLayer {}

	Variants {
		model: Quickshell.screens

		LazyLoader {
			id: wallpaperPickerLoader
			required property var modelData
			active: ((WallpaperService.pickerScreen === modelData.name
				|| (WallpaperService.pickerScreen === "" && modelData === Quickshell.screens[0]))
				&& WallpaperService.pickerOpen) || (item?.visible ?? false)
				|| (item?.retainWhenHidden ?? false)
			WallpaperPicker { modelData: wallpaperPickerLoader.modelData }
		}
	}

	Loader {
		active: true
		source: Qt.resolvedUrl("modules/panels/notifications/notification-popup.qml")
	}

	// Loaded by path so a Quickshell without polkit support only loses this dialog.
	Loader {
		active: true
		source: Qt.resolvedUrl("modules/polkit/polkit-dialog.qml")
	}

	LazyLoader { active: Debug.enabled; DebugLayer {} }
	}
