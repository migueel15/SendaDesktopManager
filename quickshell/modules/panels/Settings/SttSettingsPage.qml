import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Dictation runtime, model catalog and Hyprland shortcut settings.
Flickable {
    id: root

    contentHeight: column.implicitHeight
    clip: true

    readonly property bool shortcutReady: typeof SendaSttSettings.shortcut !== "undefined"
        && SendaSttSettings.shortcut !== null
        && typeof SendaSttSettings.shortcut.shortcut === "string"

    function displayShortcut(value) {
        return value.replace(/ntilde/gi, "ñ").replace(/ALT/gi, "Alt")
            .replace(/SUPER/gi, "Super").replace(/CTRL|CONTROL/gi, "Ctrl")
            .replace(/SHIFT/gi, "Shift");
    }

    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return "Tamaño desconocido";
        return bytes >= 1000000000 ? `${(bytes / 1000000000).toFixed(1)} GB`
            : `${(bytes / 1000000).toFixed(0)} MB`;
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 10

        Text {
            Layout.fillWidth: true
            visible: SendaSttSettings.notice !== ""
            text: SendaSttSettings.notice
            color: SendaSttSettings.noticeIsError ? Theme.colors.warning : Theme.colors.success
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(12)
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: "Motor"
            color: Theme.colors.primary
            font.family: Theme.font.heading.family
            font.pixelSize: Theme.scaled(14)
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: SendaSttSettings.runtime.installed
                    ? `Instalado${SendaSttSettings.runtime.provider ? ` · ${SendaSttSettings.runtime.provider}` : ""}`
                    : "No instalado · la descarga ocupa aproximadamente 1 GB"
                color: Theme.colors.text
                font.family: Theme.font.base.family
                font.pixelSize: Theme.scaled(12)
                wrapMode: Text.WordWrap
            }
            SettingsButton {
                visible: !SendaSttSettings.runtime.installed
                label: "Instalar motor"
                primary: true
                enabled: !SendaSttSettings.busy
                onClicked: SendaSttSettings.installRuntime()
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Modelos"
            color: Theme.colors.primary
            font.family: Theme.font.heading.family
            font.pixelSize: Theme.scaled(14)
            font.weight: Font.DemiBold
        }

        Repeater {
            model: SendaSttSettings.models

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: modelColumn.implicitHeight + 20
                radius: Theme.rounding.normal
                color: Theme.colors.surface
                border.width: 1
                border.color: modelData.active ? Theme.colors.primary : Theme.colors.surfaceVariant

                ColumnLayout {
                    id: modelColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Theme.colors.text
                        font.family: Theme.font.base.family
                        font.pixelSize: Theme.scaled(13)
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: `${(modelData.languages || []).join(", ")} · ${root.formatSize(modelData.sizeBytes)} · ${modelData.installed ? "Instalado" : "No instalado"}${modelData.active ? " · Activo" : ""}`
                        color: Theme.colors.overlay
                        font.family: Theme.font.overlay.family
                        font.pixelSize: Theme.scaled(11)
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.licenseUrl ? `<a href="${modelData.licenseUrl}" style="color:${Theme.colors.primary}">${modelData.license}</a>` : modelData.license
                        textFormat: Text.RichText
                        color: Theme.colors.overlay
                        font.family: Theme.font.overlay.family
                        font.pixelSize: Theme.scaled(11)
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        visible: SendaSttSettings.operation === "installModel" && SendaSttSettings.installingId === modelData.id
                        radius: Theme.rounding.full
                        color: Theme.colors.surfaceVariant
                        Rectangle {
                            width: parent.width * SendaSttSettings.progress
                            height: parent.height
                            radius: parent.radius
                            color: Theme.colors.accent
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Item { Layout.fillWidth: true }
                        SettingsButton {
                            visible: !modelData.installed
                            label: "Instalar"
                            primary: true
                            enabled: !SendaSttSettings.busy
                            onClicked: SendaSttSettings.installModel(modelData.id)
                        }
                        SettingsButton {
                            visible: modelData.installed && !modelData.active
                            label: "Activar"
                            enabled: !SendaSttSettings.busy
                            onClicked: SendaSttSettings.useModel(modelData.id)
                        }
                        SettingsButton {
                            visible: modelData.installed
                            label: "Borrar"
                            enabled: !SendaSttSettings.busy
                            onClicked: SendaSttSettings.removeModel(modelData.id)
                        }
                        SettingsButton {
                            visible: SendaSttSettings.operation === "installModel" && SendaSttSettings.installingId === modelData.id
                            label: "Cancelar"
                            enabled: !SendaSttSettings.cancelRequested
                            onClicked: SendaSttSettings.cancelInstall()
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Preferencias"
            color: Theme.colors.primary
            font.family: Theme.font.heading.family
            font.pixelSize: Theme.scaled(14)
            font.weight: Font.DemiBold
        }

        Rectangle {
            id: duckingRow
            Layout.fillWidth: true
            implicitHeight: duckingLabel.implicitHeight + Theme.spacing.md * 2
            radius: Theme.rounding.small
            color: duckingMouse.containsMouse && enabled ? Theme.colors.surfaceVariant : "transparent"
            enabled: !SendaSettings.busy && !SendaSttSettings.busy
            opacity: enabled ? 1 : 0.4

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing.md
                spacing: Theme.spacing.sm

                Text {
                    text: SendaSttSettings.audioDuckingEnabled ? "󰄲" : "󰄱"
                    color: SendaSttSettings.audioDuckingEnabled ? Theme.colors.primary : Theme.colors.overlay
                    font: Theme.font.icon
                }
                Text {
                    id: duckingLabel
                    Layout.fillWidth: true
                    text: "Atenuar volumen durante el dictado"
                    color: Theme.colors.text
                    font: Theme.font.body
                }
            }

            MouseArea {
                id: duckingMouse
                anchors.fill: parent
                enabled: duckingRow.enabled
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                // Keep the indicator bound to the saved value, even if saving fails.
                onClicked: SendaSttSettings.setAudioDucking(!SendaSttSettings.audioDuckingEnabled)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: SendaSttSettings.audioDuckingEnabled
            enabled: !SendaSettings.busy && !SendaSttSettings.busy
            opacity: enabled ? 1 : 0.4

            Text {
                Layout.fillWidth: true
                text: "Volumen durante el dictado (%)"
                color: Theme.colors.text
                font: Theme.font.body
            }
            SettingsField {
                id: dictationVolumeField
                Layout.preferredWidth: 65
                text: String(SendaSttSettings.audioVolume)
                placeholder: "0–100"
                onAccepted: if (volumeSave.enabled) volumeSave.clicked()
            }
            SettingsButton {
                id: volumeSave
                label: "Guardar"
                enabled: /^\d{1,3}$/.test(dictationVolumeField.text.trim())
                    && Number(dictationVolumeField.text.trim()) <= 100
                onClicked: SendaSttSettings.setAudioVolume(Number(dictationVolumeField.text.trim()))
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Al terminar o cancelar, se recupera el volumen anterior. Los cambios se aplican al siguiente dictado."
            color: Theme.colors.overlay
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(12)
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: preloadRow
            Layout.fillWidth: true
            implicitHeight: preloadLabel.implicitHeight + Theme.spacing.md * 2
            radius: Theme.rounding.small
            color: preloadMouse.containsMouse && enabled ? Theme.colors.surfaceVariant : "transparent"
            enabled: !SendaSettings.busy && !SendaSttSettings.busy
            opacity: enabled ? 1 : 0.4

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing.md
                spacing: Theme.spacing.sm

                Text {
                    text: SendaSttSettings.preloadEnabled ? "󰄲" : "󰄱"
                    color: SendaSttSettings.preloadEnabled ? Theme.colors.primary : Theme.colors.overlay
                    font: Theme.font.icon
                }
                Text {
                    id: preloadLabel
                    Layout.fillWidth: true
                    text: "Precargar modelo"
                    color: Theme.colors.text
                    font: Theme.font.body
                }
            }

            MouseArea {
                id: preloadMouse
                anchors.fill: parent
                enabled: preloadRow.enabled
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                // Keep the indicator bound to the saved value, even if saving fails.
                onClicked: SendaSttSettings.setPreload(!SendaSttSettings.preloadEnabled)
            }
        }
        Text {
            Layout.fillWidth: true
            text: SendaSttSettings.preloadState === "preparing" ? "Preparando el modelo…"
                : SendaSttSettings.preloadState === "ready" ? "Listo"
                : SendaSttSettings.preloadState === "error" ? `Error: ${SendaSttSettings.preloadError}` : "Inactivo"
            color: SendaSttSettings.preloadState === "error" ? Theme.colors.warning : Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(12)
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.preferredWidth: 110
                text: "Idioma"
                color: Theme.colors.text
                font.family: Theme.font.base.family
                font.pixelSize: Theme.scaled(12)
            }
            SettingsButton {
                label: "Español"
                primary: (SendaSettings.values.SENDA_STT_LANGUAGE || "es") === "es"
                enabled: !SendaSettings.busy
                onClicked: SendaSettings.save({ SENDA_STT_LANGUAGE: "es" }, "Idioma guardado")
            }
            SettingsButton {
                label: "Detectar"
                primary: SendaSettings.values.SENDA_STT_LANGUAGE === "auto"
                enabled: !SendaSettings.busy
                onClicked: SendaSettings.save({ SENDA_STT_LANGUAGE: "auto" }, "Idioma guardado")
            }
            SettingsField {
                id: languageField
                Layout.fillWidth: true
                placeholder: "Código de idioma (p. ej. en)"
                text: SendaSettings.values.SENDA_STT_LANGUAGE || "es"
                onAccepted: {
                    if (languageField.text.trim()) SendaSettings.save({ SENDA_STT_LANGUAGE: languageField.text.trim() }, "Idioma guardado");
                }
            }
            SettingsButton {
                label: "Guardar"
                enabled: !SendaSettings.busy && languageField.text.trim().length > 0
                onClicked: SendaSettings.save({ SENDA_STT_LANGUAGE: languageField.text.trim() }, "Idioma guardado")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.preferredWidth: 110
                text: "Al dictar"
                color: Theme.colors.text
                font.family: Theme.font.base.family
                font.pixelSize: Theme.scaled(12)
            }
            SettingsButton {
                label: "Pegar directamente"
                primary: (SendaSettings.values.SENDA_STT_PASTE_MODE || "paste") === "paste"
                enabled: !SendaSettings.busy
                onClicked: SendaSettings.save({ SENDA_STT_PASTE_MODE: "paste" }, "Modo de pegado guardado")
            }
            SettingsButton {
                label: "Solo portapapeles"
                primary: SendaSettings.values.SENDA_STT_PASTE_MODE === "clipboard"
                enabled: !SendaSettings.busy
                onClicked: SendaSettings.save({ SENDA_STT_PASTE_MODE: "clipboard" }, "Modo de pegado guardado")
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Terminales (separadas por comas)"
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(12)
        }
        RowLayout {
            Layout.fillWidth: true
            SettingsField {
                id: terminalsField
                Layout.fillWidth: true
                placeholder: "kitty, foot, Alacritty"
                text: SendaSettings.values.SENDA_STT_TERMINALS || "kitty, foot, Alacritty, org.wezfurlong.wezterm, com.mitchellh.ghostty"
            }
            SettingsButton {
                label: "Guardar"
                enabled: !SendaSettings.busy
                onClicked: SendaSettings.save({ SENDA_STT_TERMINALS: terminalsField.text.trim() }, "Terminales guardadas")
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Atajo de Hyprland"
            color: Theme.colors.primary
            font.family: Theme.font.heading.family
            font.pixelSize: Theme.scaled(14)
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            text: `Actual: ${root.displayShortcut(root.shortcutReady ? (SendaSttSettings.shortcut.shortcut || "ALT + ntilde") : "ALT + ntilde")}`
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(12)
        }
        Text {
            Layout.fillWidth: true
            visible: root.shortcutReady
            text: root.shortcutReady && SendaSttSettings.shortcut.loaded ? "Módulo cargado en Hyprland" : "Módulo no cargado en Hyprland"
            color: root.shortcutReady && SendaSttSettings.shortcut.loaded ? Theme.colors.success : Theme.colors.warning
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
        }
        RowLayout {
            Layout.fillWidth: true
            SettingsField {
                id: shortcutField
                Layout.fillWidth: true
                visible: root.shortcutReady
                placeholder: "Alt + ñ"
                text: root.displayShortcut(root.shortcutReady ? (SendaSttSettings.shortcut.shortcut || "ALT + ntilde") : "ALT + ntilde")
            }
            SettingsButton {
                visible: root.shortcutReady
                label: "Guardar atajo"
                primary: true
                enabled: !SendaSttSettings.busy && shortcutField.text.trim().length > 0
                onClicked: SendaSttSettings.setShortcut(shortcutField.text.replace(/ñ/gi, "ntilde"))
            }
        }
        Text {
            Layout.fillWidth: true
            visible: root.shortcutReady && !!SendaSttSettings.shortcut.path
            text: root.shortcutReady ? `Archivo: ${SendaSttSettings.shortcut.path || ""}` : ""
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WrapAnywhere
        }
        Text {
            Layout.fillWidth: true
            visible: root.shortcutReady && !!SendaSttSettings.shortcut.exists && !SendaSttSettings.shortcut.loaded
            text: root.shortcutReady ? `El archivo existe, pero el módulo no está cargado. Añade esta línea a tu configuración de Hyprland:\n${SendaSttSettings.shortcut.requireLine || 'require("modules.senda_binds")'}` : ""
            color: Theme.colors.warning
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WrapAnywhere
        }
        SettingsButton {
            Layout.alignment: Qt.AlignLeft
            visible: root.shortcutReady && !SendaSttSettings.shortcut.exists
            label: "Crear módulo"
            enabled: !SendaSttSettings.busy
            onClicked: SendaSttSettings.applyShortcut()
        }
        Repeater {
            model: root.shortcutReady ? (SendaSttSettings.shortcut.conflicts || []) : []
            delegate: Text {
                required property string modelData
                Layout.fillWidth: true
                text: "ALT+ñ ya está asignado"
                color: Theme.colors.warning
                font.family: Theme.font.overlay.family
                font.pixelSize: Theme.scaled(11)
                wrapMode: Text.WordWrap
            }
        }

        Item { Layout.preferredHeight: 4 }
    }
}
