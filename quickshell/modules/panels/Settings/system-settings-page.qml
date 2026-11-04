pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.common
import qs.common.components.controls
import qs.services

Flickable {
    // Where captures go when no folder is set, as the core resolves it.
    Process {
        id: screenshotDefaultDir
        property string path: "Ruta predeterminada"
        command: [ZendaSettings.binaryPath, "screenshot", "dir", "--default"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") screenshotDefaultDir.path = text.trim()
        }
    }

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
                label: "Historial del portapapeles"
                description: "Guarda en este equipo el texto copiado. No guarda imágenes ni lo que los gestores de contraseñas marcan como sensible."
                modified: ZendaSettings.values.ZENDA_CLIPBOARD_ENABLED === "false"
                onResetRequested: ZendaSettings.save({ ZENDA_CLIPBOARD_ENABLED: "" }, "Historial del portapapeles restablecido")
                ZendaSwitch {
                    checkedValue: ZendaSettings.values.ZENDA_CLIPBOARD_ENABLED !== "false"
                    enabled: !ZendaSettings.busy
                    Accessible.name: "Historial del portapapeles"
                    onToggledValue: value => ZendaSettings.save({ ZENDA_CLIPBOARD_ENABLED: String(value) }, "Historial del portapapeles guardado")
                }
            }
            ZendaRow {
                label: "Máximo de entradas"
                description: "De 1 a 1000. Se eliminan las más antiguas."
                modified: (ZendaSettings.values.ZENDA_CLIPBOARD_MAX || "") !== ""
                onResetRequested: { clipboardMaxField.text = ""; ZendaSettings.save({ ZENDA_CLIPBOARD_MAX: "" }, "Máximo de entradas restablecido"); }
                ZendaField {
                    id: clipboardMaxField
                    Layout.preferredWidth: 100
                    enabled: ZendaSettings.configLoaded
                    text: ZendaSettings.values.ZENDA_CLIPBOARD_MAX || ""
                    placeholder: "100"
                    onCommitted: ZendaSettings.save({ ZENDA_CLIPBOARD_MAX: text.trim() }, "Máximo de entradas guardado")
                }
            }
            ZendaRow {
                label: "Vaciar el historial"
                ZendaButton {
                    label: "Vaciar"
                    onClicked: ZendaClipboard.clear()
                }
            }
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
            ZendaRow {
                label: "Carpeta de capturas"
                modified: (ZendaSettings.values.ZENDA_SCREENSHOT_DIR || "") !== ""
                onResetRequested: { screenshotDirField.text = ""; ZendaSettings.save({ ZENDA_SCREENSHOT_DIR: "" }, "Carpeta de capturas restablecida"); }
                ZendaField {
                    id: screenshotDirField
                    Layout.preferredWidth: 230
                    enabled: ZendaSettings.configLoaded
                    text: ZendaSettings.values.ZENDA_SCREENSHOT_DIR || ""
                    placeholder: screenshotDefaultDir.path
                    onCommitted: ZendaSettings.save({ ZENDA_SCREENSHOT_DIR: text.trim() }, "Carpeta de capturas guardada")
                }
            }
            ZendaRow {
                label: "Desenfocar pantalla de bloqueo"
                modified: ZendaHyprlandSettings.loaded && !ZendaHyprlandSettings.values.blur
                onResetRequested: ZendaHyprlandSettings.save("--blur", true)
                ZendaSavedMark { flag: "--blur" }
                ZendaSwitch {
                    checkedValue: ZendaHyprlandSettings.loaded && ZendaHyprlandSettings.values.blur
                    enabled: ZendaHyprlandSettings.loaded
                    Accessible.name: "Desenfocar pantalla de bloqueo"
                    onToggledValue: value => ZendaHyprlandSettings.save("--blur", value)
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
