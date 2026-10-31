pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.common
import qs.services

Flickable {
    // Where captures go when no folder is set, as the core resolves it.
    Process {
        id: screenshotDefaultDir
        property string path: "Ruta predeterminada"
        command: [SendaSettings.binaryPath, "screenshot", "dir", "--default"]
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
            visible: !SendaHyprlandSettings.busy && !SendaHyprlandSettings.loaded
            text: "No se han podido cargar los ajustes."
            color: Theme.colors.overlay
            font: Theme.font.caption
            wrapMode: Text.WordWrap
        }
        SettingsButton {
            visible: !SendaHyprlandSettings.loaded && !SendaHyprlandSettings.busy
            label: "Reintentar"
            onClicked: SendaHyprlandSettings.refresh()
        }
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Historial del portapapeles"
                description: "Guarda en este equipo el texto copiado. No guarda imágenes ni lo que los gestores de contraseñas marcan como sensible."
                modified: SendaSettings.values.SENDA_CLIPBOARD_ENABLED === "false"
                onResetRequested: SendaSettings.save({ SENDA_CLIPBOARD_ENABLED: "" }, "Historial del portapapeles restablecido")
                SettingsSwitch {
                    checkedValue: SendaSettings.values.SENDA_CLIPBOARD_ENABLED !== "false"
                    enabled: !SendaSettings.busy
                    Accessible.name: "Historial del portapapeles"
                    onToggledValue: value => SendaSettings.save({ SENDA_CLIPBOARD_ENABLED: String(value) }, "Historial del portapapeles guardado")
                }
            }
            SettingsRow {
                label: "Máximo de entradas"
                description: "De 1 a 1000. Se eliminan las más antiguas."
                modified: (SendaSettings.values.SENDA_CLIPBOARD_MAX || "") !== ""
                onResetRequested: { clipboardMaxField.text = ""; SendaSettings.save({ SENDA_CLIPBOARD_MAX: "" }, "Máximo de entradas restablecido"); }
                SettingsField {
                    id: clipboardMaxField
                    Layout.preferredWidth: 100
                    enabled: SendaSettings.configLoaded
                    text: SendaSettings.values.SENDA_CLIPBOARD_MAX || ""
                    placeholder: "100"
                    onCommitted: SendaSettings.save({ SENDA_CLIPBOARD_MAX: text.trim() }, "Máximo de entradas guardado")
                }
            }
            SettingsRow {
                label: "Vaciar el historial"
                SettingsButton {
                    label: "Vaciar"
                    onClicked: SendaClipboard.clear()
                }
            }
        }
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Atajo de bloqueo"
                SettingsShortcut {
                    target: "lock"
                    enabled: SendaHyprlandSettings.loaded
                    value: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.lockShortcut : ""
                    defaultValue: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.defaultLockShortcut : ""
                }
            }
            SettingsRow {
                label: "Atajo de dictado"
                SettingsShortcut {
                    target: "dictation"
                    enabled: SendaHyprlandSettings.loaded
                    value: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.dictationShortcut : ""
                    defaultValue: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.defaultDictationShortcut : ""
                }
            }
            SettingsRow {
                label: "Atajo de captura"
                SettingsShortcut {
                    target: "screenshot"
                    enabled: SendaHyprlandSettings.loaded
                    value: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.screenshotShortcut : ""
                    defaultValue: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.defaultScreenshotShortcut : ""
                }
            }
            SettingsRow {
                label: "Carpeta de capturas"
                modified: (SendaSettings.values.SENDA_SCREENSHOT_DIR || "") !== ""
                onResetRequested: { screenshotDirField.text = ""; SendaSettings.save({ SENDA_SCREENSHOT_DIR: "" }, "Carpeta de capturas restablecida"); }
                SettingsField {
                    id: screenshotDirField
                    Layout.preferredWidth: 230
                    enabled: SendaSettings.configLoaded
                    text: SendaSettings.values.SENDA_SCREENSHOT_DIR || ""
                    placeholder: screenshotDefaultDir.path
                    onCommitted: SendaSettings.save({ SENDA_SCREENSHOT_DIR: text.trim() }, "Carpeta de capturas guardada")
                }
            }
            SettingsRow {
                label: "Desenfocar pantalla de bloqueo"
                modified: SendaHyprlandSettings.loaded && !SendaHyprlandSettings.values.blur
                onResetRequested: SendaHyprlandSettings.save("--blur", true)
                SettingsSavedMark { flag: "--blur" }
                SettingsSwitch {
                    checkedValue: SendaHyprlandSettings.loaded && SendaHyprlandSettings.values.blur
                    enabled: SendaHyprlandSettings.loaded
                    Accessible.name: "Desenfocar pantalla de bloqueo"
                    onToggledValue: value => SendaHyprlandSettings.save("--blur", value)
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: SendaHyprlandSettings.loaded
            text: SendaHyprlandSettings.loaded ? (SendaHyprlandSettings.values.moduleActive ? "Módulo activo en Hyprland" : "Módulo no activo en Hyprland") : ""
            color: SendaHyprlandSettings.loaded && SendaHyprlandSettings.values.moduleActive ? Theme.colors.overlay : Theme.colors.warning
            font: Theme.font.caption
            wrapMode: Text.WordWrap
        }
        Repeater {
            model: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.warnings : []
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
