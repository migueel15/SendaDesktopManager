pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Dictation runtime, model catalog and settings.
Flickable {
    id: root

    contentHeight: column.implicitHeight
    clip: true

    signal openSystemRequested()

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
                description: ZendaSttSettings.runtime.installed
                    ? `Instalado${ZendaSttSettings.runtime.provider ? ` · ${ZendaSttSettings.runtime.provider}` : ""}`
                    : "No instalado · la descarga ocupa aproximadamente 1 GB"
                SettingsButton {
                    visible: !ZendaSttSettings.runtime.installed
                    label: "Instalar motor"
                    primary: true
                    enabled: !ZendaSttSettings.busy
                    onClicked: ZendaSttSettings.installRuntime()
                }
            }
        }
        Text { text: "Modelos"; color: Theme.colors.primary; font: Theme.font.heading }
        Repeater {
            model: ZendaSttSettings.models

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
                        description: `${(modelCard.modelData.languages || []).join(", ")} · ${modelCard.modelData.streaming ? "Streaming · texto en vivo" : "Sin streaming · texto al terminar"} · ${root.formatSize(modelCard.modelData.sizeBytes)} · ${modelCard.modelData.installed ? "Instalado" : "No instalado"}${modelCard.modelData.active ? " · Activo" : ""}`
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelCard.modelData.licenseUrl ? `<a href="${modelCard.modelData.licenseUrl}" style="color:${Theme.colors.primary}">${modelCard.modelData.license}</a>` : modelCard.modelData.license
                        textFormat: Text.RichText
                        color: Theme.colors.overlay
                        font.family: Theme.font.overlay.family
                        font.pixelSize: Theme.scaled(11)
                        onLinkActivated: link => AppRunner.open(link)
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        visible: ZendaSttSettings.operation === "installModel" && ZendaSttSettings.installingId === modelCard.modelData.id
                        radius: Theme.rounding.full
                        color: Theme.colors.surfaceVariant
                        Rectangle {
                            width: parent.width * ZendaSttSettings.progress
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
                            enabled: !ZendaSttSettings.busy
                            onClicked: ZendaSttSettings.installModel(modelCard.modelData.id)
                        }
                        SettingsButton {
                            visible: modelCard.modelData.installed && !modelCard.modelData.active
                            label: "Activar"
                            enabled: !ZendaSttSettings.busy
                            onClicked: ZendaSttSettings.useModel(modelCard.modelData.id)
                        }
                        SettingsButton {
                            visible: modelCard.modelData.installed
                            label: "Borrar"
                            enabled: !ZendaSttSettings.busy
                            onClicked: ZendaSttSettings.removeModel(modelCard.modelData.id)
                        }
                        SettingsButton {
                            visible: ZendaSttSettings.operation === "installModel" && ZendaSttSettings.installingId === modelCard.modelData.id
                            label: "Cancelar"
                            enabled: !ZendaSttSettings.cancelRequested
                            onClicked: ZendaSttSettings.cancelInstall()
                        }
                    }
                }
            }
        }

        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Atenuar volumen durante el dictado"
                modified: !ZendaSttSettings.audioDuckingEnabled
                onResetRequested: ZendaSettings.save({ ZENDA_STT_AUDIO_DUCKING: "" }, "Atenuación restablecida")
                description: "Al terminar o cancelar se recupera el volumen anterior. Se aplica al siguiente dictado."
                SettingsSwitch {
                    checkedValue: ZendaSttSettings.audioDuckingEnabled
                    enabled: !ZendaSettings.busy && !ZendaSttSettings.busy
                    Accessible.name: "Atenuar volumen durante el dictado"
                    onToggledValue: value => ZendaSttSettings.setAudioDucking(value)
                }
            }
            SettingsRow {
                visible: ZendaSttSettings.audioDuckingEnabled
                label: "Volumen durante el dictado"
                modified: ZendaSttSettings.audioVolume !== 10
                onResetRequested: { dictationVolumeField.text = "10"; ZendaSettings.save({ ZENDA_STT_AUDIO_VOLUME: "" }, "Volumen restablecido"); }
                description: "Porcentaje entre 0 y 100. Solo se baja si el volumen actual es mayor y no está silenciado."
                SettingsField {
                    id: dictationVolumeField
                    Layout.preferredWidth: 90
                    text: String(ZendaSttSettings.audioVolume)
                    enabled: !ZendaSettings.busy && !ZendaSttSettings.busy
                    placeholder: "0–100"
                    onCommitted: {
                        const value = text.trim();
                        if (/^\d{1,3}$/.test(value) && Number(value) <= 100)
                            ZendaSttSettings.setAudioVolume(Number(value));
                        else {
                            ZendaSettings.noticeIsError = true;
                            ZendaSettings.notice = "El volumen debe ser un entero entre 0 y 100";
                        }
                    }
                }
            }
            SettingsRow {
                label: "Precargar modelo"
                modified: ZendaSttSettings.preloadEnabled
                onResetRequested: ZendaSettings.save({ ZENDA_STT_PRELOAD: "" }, "Precarga restablecida")
                description: ZendaSttSettings.preloadState === "preparing" ? "Preparando el modelo…"
                    : ZendaSttSettings.preloadState === "ready" ? "Listo"
                    : ZendaSttSettings.preloadState === "error" ? `Error: ${ZendaSttSettings.preloadError}` : "Inactivo"
                SettingsSwitch {
                    checkedValue: ZendaSttSettings.preloadEnabled
                    enabled: !ZendaSettings.busy && !ZendaSttSettings.busy
                    Accessible.name: "Precargar modelo"
                    onToggledValue: value => ZendaSttSettings.setPreload(value)
                }
            }
        }
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Idioma"
                modified: (ZendaSettings.values.ZENDA_STT_LANGUAGE || "es") !== "es"
                onResetRequested: { languageField.text = "es"; ZendaSettings.save({ ZENDA_STT_LANGUAGE: "" }, "Idioma restablecido"); }
                description: "Español o detección automática. También puedes introducir un código."
                SettingsSegments {
                    value: ZendaSettings.values.ZENDA_STT_LANGUAGE || "es"
                    options: [{ label: "Español", value: "es" }, { label: "Detectar", value: "auto" }]
                    enabled: !ZendaSettings.busy
                    onChosen: value => ZendaSettings.save({ ZENDA_STT_LANGUAGE: value }, "Idioma guardado")
                }
            }
            SettingsRow {
                label: "Código de idioma"
                description: "Por ejemplo, en."
                SettingsField {
                    id: languageField
                    Layout.preferredWidth: 120
                    text: ZendaSettings.values.ZENDA_STT_LANGUAGE || "es"
                    enabled: !ZendaSettings.busy
                    onCommitted: {
                        if (text.trim()) ZendaSettings.save({ ZENDA_STT_LANGUAGE: text.trim() }, "Idioma guardado");
                    }
                }
            }
            SettingsRow {
                label: "Al dictar"
                modified: (ZendaSettings.values.ZENDA_STT_PASTE_MODE || "paste") !== "paste"
                onResetRequested: ZendaSettings.save({ ZENDA_STT_PASTE_MODE: "" }, "Modo de pegado restablecido")
                SettingsSegments {
                    value: ZendaSettings.values.ZENDA_STT_PASTE_MODE || "paste"
                    options: [{ label: "Pegar directamente", value: "paste" }, { label: "Solo portapapeles", value: "clipboard" }]
                    enabled: !ZendaSettings.busy
                    onChosen: value => ZendaSettings.save({ ZENDA_STT_PASTE_MODE: value }, "Modo de pegado guardado")
                }
            }
            SettingsRow {
                label: "Terminales"
                modified: (ZendaSettings.values.ZENDA_STT_TERMINALS || "") !== ""
                onResetRequested: { terminalsField.text = "kitty, foot, Alacritty, org.wezfurlong.wezterm, com.mitchellh.ghostty"; ZendaSettings.save({ ZENDA_STT_TERMINALS: "" }, "Terminales restablecidas"); }
                description: "Clases de ventana separadas por comas."
                SettingsField {
                    id: terminalsField
                    Layout.preferredWidth: 220
                    Layout.fillWidth: true
                    placeholder: "kitty, foot, Alacritty"
                    text: ZendaSettings.values.ZENDA_STT_TERMINALS || "kitty, foot, Alacritty, org.wezfurlong.wezterm, com.mitchellh.ghostty"
                    enabled: !ZendaSettings.busy
                    onCommitted: ZendaSettings.save({ ZENDA_STT_TERMINALS: text.trim() }, "Terminales guardadas")
                }
            }
        }
        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Atajo de dictado"
                description: ZendaHyprlandSettings.loaded ? ZendaHyprlandSettings.values.dictationShortcut
                    : ZendaHyprlandSettings.busy ? "Consultando ajustes del sistema…" : "No se pudo consultar el atajo"
                SettingsButton {
                    label: "Abrir Sistema"
                    onClicked: root.openSystemRequested()
                }
            }
        }
    }
}
