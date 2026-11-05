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
        }
    }
}
