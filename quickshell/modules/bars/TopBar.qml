import Quickshell
import QtQuick.Layouts
import QtQuick
import QtQuick.Shapes
import qs.common
import qs.services
import qs.modules.bars.widgets
import qs.modules.themes
import qs.modules.bars.components
import qs.common.components
import Quickshell.Io
import Quickshell.Wayland

Variants {
	id: root
	model: Quickshell.screens

	required property var panelController

	delegate: PanelWindow {
		id: topbar

		WlrLayershell.namespace: "Zenda:TopBar"

		required property var modelData
		screen: modelData
		readonly property string screenName: modelData.name

		property var panelController: root.panelController

		exclusionMode: ExclusionMode.Normal
		exclusiveZone: Theme.barSize
		mask: Region { item: bar }

		focusable: false
		aboveWindows: true

		color: "transparent"

		anchors {
			top: true
			left: true
			right: true
			// bottom: true
		}

		implicitHeight: Theme.barSize + Theme.frameShadowReach

		LazyLoader {
			active: ((ZendaTheme.pickerScreen === topbar.screenName
			|| (ZendaTheme.pickerScreen === "" && topbar.modelData === Quickshell.screens[0]))
			&& ZendaTheme.pickerOpen) || (item?.visible ?? false) || (item?.retainWhenHidden ?? false)
			PanelWindow {
				id: themeWindow
				readonly property bool retainWhenHidden: themePicker.editing
				screen: topbar.modelData
				// Full screen under the bar, so a click outside the popup can close it,
				// as the dashboard does.
				anchors { top: true; bottom: true; left: true; right: true }
				exclusionMode: ExclusionMode.Normal
				exclusiveZone: 0
				WlrLayershell.namespace: "Zenda:ThemePicker"
				WlrLayershell.layer: WlrLayer.Overlay
				WlrLayershell.keyboardFocus: themePicker.expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
				color: "transparent"
				visible: themePicker.onPickerScreen && (ZendaTheme.pickerOpen || themePicker.height > 0.01)
				// While open the whole window takes input (backdrop); while folding, only the popup.
				mask: Region { item: themePicker.expanded ? backdrop : themePicker }

				MouseArea {
					id: backdrop
					anchors.fill: parent
					enabled: themePicker.expanded
					onPressed: ZendaTheme.closePicker()
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
					maximumHeight: Math.max(0, themeWindow.height - themePicker.shadowSpace)
					onPickerScreen: ZendaTheme.pickerScreen === topbar.screenName
						|| (ZendaTheme.pickerScreen === "" && topbar.modelData === Quickshell.screens[0])
				}
			}
		}

		// The window reaches below the bar for the top corners and the frame shadow;
		// only this bar area takes input and reserves space.
		Item {
			id: bar
			width: parent.width
			height: Theme.barSize

			Rectangle {
				anchors.fill: parent
				z: -2
				color: Theme.colors.background
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
				id: launcherProc
				command: [Quickshell.env("ZENDA_BIN") || "zenda", "launcher", "toggle", "--screen", topbar.screenName]
				onExited: exitCode => { if (exitCode !== 0) console.warn("Launcher command failed:", exitCode); }
			}

			// Left section: logo, workspaces, and the active task. Same 4 px gap and
			// 8 px edge margin as the right section.
			RowLayout {
				height: parent.height
				anchors.left: parent.left
				anchors.leftMargin: 8
				spacing: 4

				// Logo opens the application launcher on this monitor.
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

					// Zenda symbol drawn with the active theme. Same geometry as
					// assets/zenda-logo.svg (120×120): top bar secondary, outer face
					// white, inner fold accent darkened towards base, bottom bar primary.
					Shape {
						anchors.centerIn: parent
						width: 22
						height: 22
						preferredRendererType: Shape.CurveRenderer

						transform: Scale { xScale: 22 / 120; yScale: 22 / 120 }

						ShapePath {
							strokeWidth: -1
							fillColor: Qt.tint(Theme.colors.base, Qt.alpha(Theme.colors.accent, 0.63))
							PathPolyline { path: [Qt.point(62, 36), Qt.point(106, 36), Qt.point(58, 84), Qt.point(62, 36)] }
						}
						ShapePath {
							strokeWidth: -1
							fillColor: Theme.colors.white
							PathPolyline { path: [Qt.point(62, 36), Qt.point(58, 84), Qt.point(14, 84), Qt.point(62, 36)] }
						}
						ShapePath {
							strokeWidth: -1
							fillColor: Theme.colors.secondary
							PathPolyline { path: [Qt.point(12, 14), Qt.point(84, 14), Qt.point(106, 36), Qt.point(34, 36), Qt.point(12, 14)] }
						}
						ShapePath {
							strokeWidth: -1
							fillColor: Theme.colors.primary
							PathPolyline { path: [Qt.point(14, 84), Qt.point(86, 84), Qt.point(108, 106), Qt.point(36, 106), Qt.point(14, 84)] }
						}
					}

					MouseArea {
						id: logoMouse
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: { if (!launcherProc.running) launcherProc.running = true; }
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

				Loader {
					id: nowPlaying
					Layout.preferredHeight: parent.height * 0.8
					Layout.alignment: Qt.AlignVCenter
					active: ZendaSettings.configLoaded && ZendaSettings.values.ZENDA_WIDGET_SPOTIFY !== "false"
					visible: active && (item?.hasTrack ?? false)
					sourceComponent: NowPlaying {}
				}

				Loader {
					id: discordVoice
					Layout.preferredHeight: parent.height * 0.8
					Layout.alignment: Qt.AlignVCenter
					active: ZendaSettings.configLoaded && ZendaSettings.values.ZENDA_WIDGET_DISCORD !== "false"
					visible: active && (item?.voiceState.authenticated || (item?.voiceState.connected && item?.voiceState.auth_required))
					sourceComponent: DiscordVoice {}
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

		BarCorner {
			x: Theme.frameSize
			y: Theme.barSize
			position: "top-left"
		}

		BarCorner {
			x: topbar.width - Theme.frameSize - width
			y: Theme.barSize
			position: "top-right"
		}

		FrameShadow {
			y: Theme.barSize
			width: topbar.width
			height: Theme.frameShadowReach
			screenWidth: topbar.screen.width
			screenHeight: topbar.screen.height
			originY: Theme.barSize
		}
	}
}
