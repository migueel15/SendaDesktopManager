pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.components.controls
import qs.services

// Every Zenda keyboard shortcut in one place, written to the Hyprland module.
Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        Text {
            Layout.fillWidth: true
            visible: !ZendaHyprlandSettings.busy && !ZendaHyprlandSettings.loaded
            text: "No se han podido cargar los ajustes."
            color: Theme.colors.overlay
            font: Theme.font.caption
            wrapMode: Text.WordWrap
        }
        ZendaButton {
            visible: !ZendaHyprlandSettings.loaded && !ZendaHyprlandSettings.busy
            label: "Reintentar"
            onClicked: ZendaHyprlandSettings.refresh()
        }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Atajo de bloqueo"
                ZendaShortcut {
                    target: "lock"
                    enabled: ZendaHyprlandSettings.loaded
                    value: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.lockShortcut : ""
                    defaultValue: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.defaultLockShortcut : ""
                }
            }
            ZendaRow {
                label: "Atajo de dictado"
                ZendaShortcut {
                    target: "dictation"
                    enabled: ZendaHyprlandSettings.loaded
                    value: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.dictationShortcut : ""
                    defaultValue: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.defaultDictationShortcut : ""
                }
            }
            ZendaRow {
                label: "Atajo de captura"
                ZendaShortcut {
                    target: "screenshot"
                    enabled: ZendaHyprlandSettings.loaded
                    value: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.screenshotShortcut : ""
                    defaultValue: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.defaultScreenshotShortcut : ""
                }
            }
            ZendaRow {
                label: "Atajo del launcher"
                ZendaShortcut {
                    target: "launcher"
                    enabled: ZendaHyprlandSettings.loaded
                    value: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.launcherShortcut : ""
                    defaultValue: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.defaultLauncherShortcut : ""
                }
            }
            ZendaRow {
                label: "Atajo de emojis"
                ZendaShortcut {
                    target: "emoji"
                    enabled: ZendaHyprlandSettings.loaded
                    value: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.emojiShortcut : ""
                    defaultValue: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.defaultEmojiShortcut : ""
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: ZendaHyprlandSettings.loaded
            text: ZendaHyprlandSettings.loaded ? (ZendaHyprlandSettings.values.moduleActive ? "Módulo activo en Hyprland" : "Módulo no activo en Hyprland") : ""
            color: ZendaHyprlandSettings.loaded && ZendaHyprlandSettings.values.moduleActive ? Theme.colors.overlay : Theme.colors.warning
            font: Theme.font.caption
            wrapMode: Text.WordWrap
        }
        Repeater {
            model: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.warnings : []
            delegate: Text {
                required property string modelData
                Layout.fillWidth: true
                text: modelData
                color: Theme.colors.warning
                font: Theme.font.caption
                wrapMode: Text.WrapAnywhere
            }
        }
    }
}
