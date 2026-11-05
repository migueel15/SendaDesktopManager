pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import qs.common
import qs.common.components.icons
import qs.common.components.controls
import qs.services

// Dictation runtime, model catalog and settings.
Flickable {
    id: root

    contentHeight: column.implicitHeight
    clip: true

    property bool showAllModels: false
    readonly property int otherModelCount: ZendaSttSettings.models.filter(model => !model.active).length

    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return "Tamaño desconocido";
        return bytes >= 1000000000 ? `${(bytes / 1000000000).toFixed(1)} GB`
            : `${(bytes / 1000000).toFixed(0)} MB`;
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Motor"
                description: ZendaSttSettings.runtime.installed
                    ? `Instalado${ZendaSttSettings.runtime.provider ? ` · ${ZendaSttSettings.runtime.provider}` : ""}`
                    : "No instalado · la descarga ocupa aproximadamente 1 GB"
                ZendaButton {
                    visible: !ZendaSttSettings.runtime.installed
                    label: "Instalar motor"
                    primary: true
                    enabled: !ZendaSttSettings.busy
                    onClicked: ZendaSttSettings.installRuntime()
                }
            }
        }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Atenuar volumen durante el dictado"
                modified: !ZendaSttSettings.audioDuckingEnabled
                onResetRequested: ZendaSettings.save({ ZENDA_STT_AUDIO_DUCKING: "" }, "Atenuación restablecida")
                description: "Al terminar o cancelar se recupera el volumen anterior. Se aplica al siguiente dictado."
                ZendaSwitch {
                    checkedValue: ZendaSttSettings.audioDuckingEnabled
                    enabled: !ZendaSettings.busy && !ZendaSttSettings.busy
                    Accessible.name: "Atenuar volumen durante el dictado"
                    onToggledValue: value => ZendaSttSettings.setAudioDucking(value)
                }
            }
            ZendaRow {
                visible: ZendaSttSettings.audioDuckingEnabled
                label: "Volumen durante el dictado"
                modified: ZendaSttSettings.audioVolume !== 10
                onResetRequested: { dictationVolumeField.text = "10"; ZendaSettings.save({ ZENDA_STT_AUDIO_VOLUME: "" }, "Volumen restablecido"); }
                description: "Porcentaje entre 0 y 100. Solo se baja si el volumen actual es mayor y no está silenciado."
                ZendaField {
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
            ZendaRow {
                label: "Precargar modelo"
                modified: ZendaSttSettings.preloadEnabled
                onResetRequested: ZendaSettings.save({ ZENDA_STT_PRELOAD: "" }, "Precarga restablecida")
                description: ZendaSttSettings.preloadState === "preparing" ? "Preparando el modelo…"
                    : ZendaSttSettings.preloadState === "ready" ? "Listo"
                    : ZendaSttSettings.preloadState === "error" ? `Error: ${ZendaSttSettings.preloadError}` : "Inactivo"
                ZendaSwitch {
                    checkedValue: ZendaSttSettings.preloadEnabled
                    enabled: !ZendaSettings.busy && !ZendaSttSettings.busy
                    Accessible.name: "Precargar modelo"
                    onToggledValue: value => ZendaSttSettings.setPreload(value)
                }
            }
            ZendaRow {
                label: "Mostrar texto en vivo"
                modified: !ZendaSttSettings.liveTextEnabled
                onResetRequested: ZendaSettings.save({ ZENDA_STT_LIVE_TEXT: "" }, "Texto en vivo restablecido")
                description: "El dock muestra lo que vas diciendo. Desactivado, solo muestra las barras; el texto se entrega igual al terminar."
                ZendaSwitch {
                    checkedValue: ZendaSttSettings.liveTextEnabled
                    enabled: !ZendaSettings.busy && !ZendaSttSettings.busy
                    Accessible.name: "Mostrar texto en vivo"
                    onToggledValue: value => ZendaSttSettings.setLiveText(value)
                }
            }
        }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Idioma"
                modified: (ZendaSettings.values.ZENDA_STT_LANGUAGE || "es") !== "es"
                onResetRequested: { languageField.text = "es"; ZendaSettings.save({ ZENDA_STT_LANGUAGE: "" }, "Idioma restablecido"); }
                description: "Español o detección automática. También puedes introducir un código."
                ZendaSegments {
                    value: ZendaSettings.values.ZENDA_STT_LANGUAGE || "es"
                    options: [{ label: "Español", value: "es" }, { label: "Detectar", value: "auto" }]
                    enabled: !ZendaSettings.busy
                    onChosen: value => ZendaSettings.save({ ZENDA_STT_LANGUAGE: value }, "Idioma guardado")
                }
            }
            ZendaRow {
                label: "Código de idioma"
                description: "Por ejemplo, en."
                ZendaField {
                    id: languageField
                    Layout.preferredWidth: 120
                    text: ZendaSettings.values.ZENDA_STT_LANGUAGE || "es"
                    enabled: !ZendaSettings.busy
                    onCommitted: {
                        if (text.trim()) ZendaSettings.save({ ZENDA_STT_LANGUAGE: text.trim() }, "Idioma guardado");
                    }
                }
            }
            ZendaRow {
                label: "Al dictar"
                modified: (ZendaSettings.values.ZENDA_STT_PASTE_MODE || "paste") !== "paste"
                onResetRequested: ZendaSettings.save({ ZENDA_STT_PASTE_MODE: "" }, "Modo de pegado restablecido")
                ZendaSegments {
                    value: ZendaSettings.values.ZENDA_STT_PASTE_MODE || "paste"
                    options: [{ label: "Pegar directamente", value: "paste" }, { label: "Solo portapapeles", value: "clipboard" }]
                    enabled: !ZendaSettings.busy
                    onChosen: value => ZendaSettings.save({ ZENDA_STT_PASTE_MODE: value }, "Modo de pegado guardado")
                }
            }
            ZendaRow {
                label: "Terminales"
                modified: (ZendaSettings.values.ZENDA_STT_TERMINALS || "") !== ""
                onResetRequested: { terminalsField.text = "kitty, foot, Alacritty, org.wezfurlong.wezterm, com.mitchellh.ghostty"; ZendaSettings.save({ ZENDA_STT_TERMINALS: "" }, "Terminales restablecidas"); }
                description: "Clases de ventana separadas por comas."
                ZendaField {
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
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.sm
            Text { text: "Modelos"; color: Theme.colors.primary; font: Theme.font.heading; Layout.fillWidth: true }
            ZendaButton {
                visible: root.otherModelCount > 0
                label: root.showAllModels ? "Ocultar otros modelos" : `Ver otros modelos (${root.otherModelCount})`
                onClicked: root.showAllModels = !root.showAllModels
            }
        }
        Text {
            visible: !root.showAllModels && root.otherModelCount === ZendaSttSettings.models.length && ZendaSttSettings.models.length > 0
            text: "Ningún modelo activo. Abre la lista para instalar uno."
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
        }
        Repeater {
            model: ZendaSttSettings.models

            delegate: ZendaGroup {
                id: modelCard
                required property var modelData
                readonly property bool installing: ZendaSttSettings.operation === "installModel"
                    && ZendaSttSettings.installingId === modelCard.modelData.id
                readonly property var languages: modelCard.modelData.languages || []
                Layout.fillWidth: true
                // The active model, or one being installed, stays visible when the list is collapsed.
                visible: root.showAllModels || modelCard.modelData.active || modelCard.installing
                border.width: modelCard.modelData.active ? 1 : 0
                border.color: Theme.colors.accent

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.md

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.sm

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.sm
                            Text {
                                Layout.fillWidth: true
                                text: modelCard.modelData.name
                                elide: Text.ElideRight
                                color: Theme.colors.text
                                font: Theme.font.heading
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.sm
                            ModelChip {
                                icon: "󰗊"
                                label: modelCard.languages.length > 3
                                    ? `${modelCard.languages.slice(0, 3).join(" · ")} +${modelCard.languages.length - 3}`
                                    : modelCard.languages.join(" · ")
                                tip: modelCard.languages.join(", ")
                            }
                            ModelChip {
                                icon: modelCard.modelData.streaming ? "󱐋" : "󰔟"
                                label: modelCard.modelData.streaming ? "En vivo" : "Por rondas"
                                tip: modelCard.modelData.streaming ? "Muestra el texto mientras hablas" : "Muestra el texto mientras hablas, retranscribiendo por rondas"
                            }
                            ModelChip {
                                icon: "󰋊"
                                label: root.formatSize(modelCard.modelData.sizeBytes)
                            }
                            ModelChip {
                                visible: !!modelCard.modelData.license
                                icon: "󰗑"
                                label: modelCard.modelData.license || ""
                                link: modelCard.modelData.licenseUrl || ""
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: modelCard.installing
                            text: ZendaSttSettings.cancelRequested ? "Cancelando…"
                                : ZendaSttSettings.installPhase === "extract"
                                    ? `Paso 2 de 2 · Descomprimiendo e instalando · ${Math.round(ZendaSttSettings.progress * 100)} %`
                                : ZendaSttSettings.installPhase === "download"
                                    ? `Paso 1 de 2 · Descargando · ${Math.round(ZendaSttSettings.progress * 100)} %`
                                : "Preparando la descarga…"
                            color: Theme.colors.overlay
                            font: Theme.font.caption
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5
                            visible: modelCard.installing
                            radius: Theme.rounding.full
                            color: Theme.colors.surfaceVariant
                            Rectangle {
                                width: parent.width * ZendaSttSettings.progress
                                height: parent.height
                                radius: parent.radius
                                color: Theme.colors.accent
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Theme.spacing.sm
                        ModelChip {
                            visible: modelCard.modelData.active
                            icon: "󰄬"
                            label: "Activo"
                            tint: Theme.colors.success
                        }
                        ModelChip {
                            visible: modelCard.modelData.installed && !modelCard.modelData.active
                            icon: "󰗠"
                            label: "Instalado"
                        }
                        ZendaButton {
                            visible: !modelCard.modelData.installed && !modelCard.installing
                            label: "Instalar"
                            primary: true
                            enabled: !ZendaSttSettings.busy
                            onClicked: ZendaSttSettings.installModel(modelCard.modelData.id)
                        }
                        ZendaButton {
                            visible: modelCard.modelData.installed && !modelCard.modelData.active
                            label: "Usar"
                            enabled: !ZendaSttSettings.busy
                            onClicked: ZendaSttSettings.useModel(modelCard.modelData.id)
                        }
                        ZendaButton {
                            visible: modelCard.modelData.installed
                            label: "Borrar"
                            enabled: !ZendaSttSettings.busy
                            onClicked: ZendaSttSettings.removeModel(modelCard.modelData.id)
                        }
                        ZendaIconButton {
                            visible: modelCard.installing
                            icon: "󰅖"
                            accessibleLabel: "Cancelar instalación"
                            enabled: !ZendaSttSettings.cancelRequested
                            onClicked: ZendaSttSettings.cancelInstall()
                        }
                    }
                }
            }
        }
    }

    // Small pill with an icon and a short value; opens link when given.
    component ModelChip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property string tip: ""
        property string link: ""
        property color tint: Theme.colors.overlay
        implicitWidth: chipRow.implicitWidth + 2 * Theme.spacing.sm
        implicitHeight: chipRow.implicitHeight + Theme.spacing.xs * 2
        radius: Theme.rounding.full
        color: Qt.alpha(chip.tint, 0.12)
        ZendaStateLayer { hovered: chipHover.hovered && chip.link !== "" }
        Accessible.name: chip.tip || chip.label
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spacing.xs
            ZendaIcon { text: chip.icon; color: chip.tint; anchors.verticalCenter: parent.verticalCenter }
            Text { text: chip.label; color: Theme.colors.textMuted; font: Theme.font.caption; anchors.verticalCenter: parent.verticalCenter }
        }
        HoverHandler { id: chipHover; cursorShape: chip.link ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: !!chip.link; onTapped: AppRunner.open(chip.link) }
        ToolTip.visible: !!chip.tip && chipHover.hovered
        ToolTip.text: chip.tip
    }
}
