pragma ComponentBehavior: Bound

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
        spacing: Theme.spacing.md
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Motor"
                description: SendaSttSettings.runtime.installed
                    ? `Instalado${SendaSttSettings.runtime.provider ? ` · ${SendaSttSettings.runtime.provider}` : ""}`
                    : "No instalado · la descarga ocupa aproximadamente 1 GB"
                SettingsButton {
                    visible: !SendaSttSettings.runtime.installed
                    label: "Instalar motor"
                    primary: true
                    enabled: !SendaSttSettings.busy
                    onClicked: SendaSttSettings.installRuntime()
                }
            }
        }
        Text { text: "Modelos"; color: Theme.colors.primary; font: Theme.font.heading }
        Repeater {
            model: SendaSttSettings.models

            delegate: SettingsGroup {
                id: modelCard
                required property var modelData
                Layout.fillWidth: true

                ColumnLayout {
                    id: modelColumn
                    Layout.fillWidth: true
                    spacing: Theme.spacing.sm

                    SettingsRow {
                        separator: false
                        label: modelCard.modelData.name
                        description: `${(modelCard.modelData.languages || []).join(", ")} · ${root.formatSize(modelCard.modelData.sizeBytes)} · ${modelCard.modelData.installed ? "Instalado" : "No instalado"}${modelCard.modelData.active ? " · Activo" : ""}`
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelCard.modelData.licenseUrl ? `<a href="${modelCard.modelData.licenseUrl}" style="color:${Theme.colors.primary}">${modelCard.modelData.license}</a>` : modelCard.modelData.license
                        textFormat: Text.RichText
                        color: Theme.colors.overlay
                        font.family: Theme.font.overlay.family
                        font.pixelSize: Theme.scaled(11)
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        visible: SendaSttSettings.operation === "installModel" && SendaSttSettings.installingId === modelCard.modelData.id
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
                        spacing: Theme.spacing.sm
                        Item { Layout.fillWidth: true }
                        SettingsButton {
                            visible: !modelCard.modelData.installed
                            label: "Instalar"
                            primary: true
                            enabled: !SendaSttSettings.busy
                            onClicked: SendaSttSettings.installModel(modelCard.modelData.id)
                        }
                        SettingsButton {
                            visible: modelCard.modelData.installed && !modelCard.modelData.active
                            label: "Activar"
                            enabled: !SendaSttSettings.busy
                            onClicked: SendaSttSettings.useModel(modelCard.modelData.id)
                        }
                        SettingsButton {
                            visible: modelCard.modelData.installed
                            label: "Borrar"
                            enabled: !SendaSttSettings.busy
                            onClicked: SendaSttSettings.removeModel(modelCard.modelData.id)
                        }
                        SettingsButton {
                            visible: SendaSttSettings.operation === "installModel" && SendaSttSettings.installingId === modelCard.modelData.id
                            label: "Cancelar"
                            enabled: !SendaSttSettings.cancelRequested
                            onClicked: SendaSttSettings.cancelInstall()
                        }
                    }
                }
            }
        }

        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Atenuar volumen durante el dictado"
                description: "Al terminar o cancelar se recupera el volumen anterior. Se aplica al siguiente dictado."
                SettingsSwitch {
                    checkedValue: SendaSttSettings.audioDuckingEnabled
                    enabled: !SendaSettings.busy && !SendaSttSettings.busy
                    Accessible.name: "Atenuar volumen durante el dictado"
                    onToggledValue: value => SendaSttSettings.setAudioDucking(value)
                }
            }
            SettingsRow {
                visible: SendaSttSettings.audioDuckingEnabled
                label: "Volumen durante el dictado"
                description: "Porcentaje entre 0 y 100."
                SettingsField {
                    id: dictationVolumeField
                    Layout.preferredWidth: 90
                    text: String(SendaSttSettings.audioVolume)
                    enabled: !SendaSettings.busy && !SendaSttSettings.busy
                    placeholder: "0–100"
                    onCommitted: {
                        const value = text.trim();
                        if (/^\d{1,3}$/.test(value) && Number(value) <= 100)
                            SendaSttSettings.setAudioVolume(Number(value));
                        else {
                            SendaSettings.noticeIsError = true;
                            SendaSettings.notice = "El volumen debe ser un entero entre 0 y 100";
                        }
                    }
                }
            }
            SettingsRow {
                label: "Precargar modelo"
                description: SendaSttSettings.preloadState === "preparing" ? "Preparando el modelo…"
                    : SendaSttSettings.preloadState === "ready" ? "Listo"
                    : SendaSttSettings.preloadState === "error" ? `Error: ${SendaSttSettings.preloadError}` : "Inactivo"
                SettingsSwitch {
                    checkedValue: SendaSttSettings.preloadEnabled
                    enabled: !SendaSettings.busy && !SendaSttSettings.busy
                    Accessible.name: "Precargar modelo"
                    onToggledValue: value => SendaSttSettings.setPreload(value)
                }
            }
        }
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Idioma"
                description: "Español o detección automática. También puedes introducir un código."
                SettingsSegments {
                    value: SendaSettings.values.SENDA_STT_LANGUAGE || "es"
                    options: [{ label: "Español", value: "es" }, { label: "Detectar", value: "auto" }]
                    enabled: !SendaSettings.busy
                    onChosen: value => SendaSettings.save({ SENDA_STT_LANGUAGE: value }, "Idioma guardado")
                }
            }
            SettingsRow {
                label: "Código de idioma"
                description: "Por ejemplo, en."
                SettingsField {
                    id: languageField
                    Layout.preferredWidth: 120
                    text: SendaSettings.values.SENDA_STT_LANGUAGE || "es"
                    enabled: !SendaSettings.busy
                    onCommitted: {
                        if (text.trim()) SendaSettings.save({ SENDA_STT_LANGUAGE: text.trim() }, "Idioma guardado");
                    }
                }
            }
            SettingsRow {
                label: "Al dictar"
                SettingsSegments {
                    value: SendaSettings.values.SENDA_STT_PASTE_MODE || "paste"
                    options: [{ label: "Pegar directamente", value: "paste" }, { label: "Solo portapapeles", value: "clipboard" }]
                    enabled: !SendaSettings.busy
                    onChosen: value => SendaSettings.save({ SENDA_STT_PASTE_MODE: value }, "Modo de pegado guardado")
                }
            }
            SettingsRow {
                label: "Terminales"
                description: "Clases de ventana separadas por comas."
                SettingsField {
                    id: terminalsField
                    Layout.preferredWidth: 220
                    Layout.fillWidth: true
                    placeholder: "kitty, foot, Alacritty"
                    text: SendaSettings.values.SENDA_STT_TERMINALS || "kitty, foot, Alacritty, org.wezfurlong.wezterm, com.mitchellh.ghostty"
                    enabled: !SendaSettings.busy
                    onCommitted: SendaSettings.save({ SENDA_STT_TERMINALS: text.trim() }, "Terminales guardadas")
                }
            }
        }
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Atajo de Hyprland"
                description: root.shortcutReady && SendaSttSettings.shortcut.loaded ? "Módulo cargado en Hyprland" : "Módulo no cargado en Hyprland"
                SettingsField {
                    id: shortcutField
                    Layout.preferredWidth: 180
                    Layout.fillWidth: true
                    visible: root.shortcutReady
                    enabled: !SendaSttSettings.busy
                    placeholder: "Alt + ñ"
                    text: root.displayShortcut(root.shortcutReady ? (SendaSttSettings.shortcut.shortcut || "ALT + ntilde") : "ALT + ntilde")
                    onCommitted: if (text.trim()) SendaSttSettings.setShortcut(text.replace(/ñ/gi, "ntilde"))
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
                Layout.alignment: Qt.AlignRight
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

        }
    }
}
