import Quickshell
import QtQuick.Layouts
import QtQuick
import qs.common
import qs.services
import qs.modules.bars.widgets
import qs.modules.themes
import Quickshell.Io
import Quickshell.Wayland

Variants {
	id: root
	model: Quickshell.screens

	required property var panelController

	delegate: PanelWindow {
		id: topbar

		WlrLayershell.namespace: "Senda:TopBar"

		required property var modelData
		screen: modelData
		readonly property string screenName: modelData.name

		property var panelController: root.panelController

		exclusionMode: ExclusionMode.Auto

		focusable: false
		aboveWindows: true

		color: Theme.colors.background

		anchors {
			top: true
			left: true
			right: true
			// bottom: true
		}

		implicitHeight: Theme.barSize

		PanelWindow {
			id: themeWindow
			screen: topbar.modelData
			// Full screen under the bar, so a click outside the popup can close it,
			// as the dashboard does.
			anchors { top: true; bottom: true; left: true; right: true }
			margins.top: topbar.implicitHeight
			exclusionMode: ExclusionMode.Ignore
			WlrLayershell.namespace: "Senda:ThemePicker"
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.keyboardFocus: themePicker.expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
			color: "transparent"
			visible: themePicker.onPickerScreen && (SendaTheme.pickerOpen || themePicker.height > 0.01)
			// While open the whole window takes input (backdrop); while folding, only the popup.
			mask: Region { item: themePicker.expanded ? backdrop : themePicker }

			MouseArea {
				id: backdrop
				anchors.fill: parent
				enabled: themePicker.expanded
				onPressed: SendaTheme.closePicker()
			}

			// Swallows clicks on empty parts of the popup so they do not reach the backdrop.
			MouseArea {
				x: themePicker.x
				y: themePicker.y
				width: themePicker.width
				height: themePicker.height
				enabled: themePicker.expanded
			}

			ThemePicker {
				id: themePicker
				width: Math.min(Theme.scaled(760), themeWindow.width)
				x: Math.round((themeWindow.width - width) / 2)
				y: -collapseLift
				maximumHeight: themeWindow.height
				onPickerScreen: SendaTheme.pickerScreen === topbar.screenName
					|| (SendaTheme.pickerScreen === "" && topbar.modelData === Quickshell.screens[0])
			}
		}

		// Clicks on empty parts of the bar close the open panel. Buttons sit above
		// this area, so they still receive their clicks.
		MouseArea {
			anchors.fill: parent
			z: -1
			enabled: OverlayService.currentPanel !== ""
			onPressed: OverlayService.closeCurrentPanel()
		}

		Process {
			id: reloadProc
			running: false
			command: ["bash", Qt.resolvedUrl("../../utils/reloadHyprland.sh").toString().replace("file://", "")]

			onRunningChanged: {
				if (!running) {
					// Process finished, reset state
					reloadProc.running = false;
				}
			}
		}

		// Left section: logo, workspaces, and the active task. Same 4 px gap and
		// 8 px edge margin as the right section.
		RowLayout {
			height: parent.height
			anchors.left: parent.left
			anchors.leftMargin: 8
			spacing: 4

			// Logo with the same hover pill as the other bar buttons. Click reloads Hyprland.
			Rectangle {
				Layout.preferredWidth: Theme.barButtonSize
				Layout.preferredHeight: Theme.barButtonSize
				Layout.alignment: Qt.AlignVCenter
				radius: Theme.rounding.normal
				color: logoMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

				Behavior on color {
					ColorAnimation {
						duration: 150
					}
				}

				Image {
					anchors.centerIn: parent
					width: 22
					height: 22
					source: Qt.resolvedUrl("../../assets/senda-logo.svg")
					sourceSize: Qt.size(22, 22)
					fillMode: Image.PreserveAspectFit
					smooth: true
				}

				MouseArea {
					id: logoMouse
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: reloadProc.running = true
				}
			}

			// Separates the logo from the workspaces.
			Rectangle {
				Layout.preferredWidth: 1
				Layout.preferredHeight: parent.height * 0.4
				Layout.leftMargin: 4
				Layout.rightMargin: 4
				color: Theme.colors.surfaceVariant
			}

			Workspaces {}

			TasksToggle {
				Layout.leftMargin: 4
				screenName: topbar.screenName
			}

		}

		Clock {
			id: barClock
			screenName: topbar.screenName
		}

		UpdateNotice {
			screenName: topbar.screenName
			anchors.verticalCenter: parent.verticalCenter
			anchors.left: barClock.right
			anchors.leftMargin: 12
		}

		// Right section, left to right: what is playing now (media, voice),
		// background apps (tray), quick toggles, and the panels.
		RowLayout {
			spacing: 4
			height: parent.height
			anchors.right: parent.right
			anchors.rightMargin: 8

			NowPlaying {
				id: nowPlaying
			}

			DiscordVoice {
				id: discordVoice
			}

			// Separates the contextual widgets from the fixed ones.
			Rectangle {
				visible: nowPlaying.visible || discordVoice.visible
				Layout.preferredWidth: 1
				Layout.preferredHeight: parent.height * 0.4
				Layout.leftMargin: 6
				Layout.rightMargin: 6
				color: Theme.colors.surfaceVariant
			}

			SystemTray {
				Layout.rightMargin: 6
			}

			KeyboardToggler {}

			Notifications {
				screenName: topbar.screenName
			}

			ControlPanel {
				onClicked: {
					OverlayService.togglePanel("controlCenter", topbar.screenName);
				}
			}
		}
	}
}
