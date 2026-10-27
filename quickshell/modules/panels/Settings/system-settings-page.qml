pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    Connections {
        target: SendaHyprlandSettings
        function onValuesChanged() {
            lockField.text = SendaHyprlandSettings.values.lockShortcut;
            dictationField.text = SendaHyprlandSettings.values.dictationShortcut;
            idleField.text = String(SendaHyprlandSettings.values.idleSeconds);
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        Text {
            Layout.fillWidth: true
            visible: SendaHyprlandSettings.busy || !SendaHyprlandSettings.loaded
            text: SendaHyprlandSettings.writing ? "Guardando ajustes…"
                : SendaHyprlandSettings.busy ? "Consultando ajustes…" : "No se han podido cargar los ajustes."
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
                label: "Atajo de bloqueo"
                SettingsField {
                    id: lockField
                    Layout.preferredWidth: 180
                    enabled: SendaHyprlandSettings.loaded && !SendaHyprlandSettings.busy
                    text: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.lockShortcut : ""
                    placeholder: "Super + L"
                    onCommitted: if (!SendaHyprlandSettings.save("--lock-shortcut", text)) text = SendaHyprlandSettings.values.lockShortcut
                }
            }
            SettingsRow {
                label: "Atajo de dictado"
                SettingsField {
                    id: dictationField
                    Layout.preferredWidth: 180
                    enabled: SendaHyprlandSettings.loaded && !SendaHyprlandSettings.busy
                    text: SendaHyprlandSettings.loaded ? SendaHyprlandSettings.values.dictationShortcut : ""
                    placeholder: "Alt + ñ"
                    onCommitted: if (!SendaHyprlandSettings.save("--dictation-shortcut", text.replace(/ñ/gi, "ntilde"))) text = SendaHyprlandSettings.values.dictationShortcut
                }
            }
            SettingsRow {
                label: "Tiempo de inactividad"
                description: "Segundos, de 0 a 86400. 0 desactiva el bloqueo automático."
                SettingsField {
                    id: idleField
                    Layout.preferredWidth: 100
                    enabled: SendaHyprlandSettings.loaded && !SendaHyprlandSettings.busy
                    text: SendaHyprlandSettings.loaded ? String(SendaHyprlandSettings.values.idleSeconds) : ""
                    placeholder: "Segundos"
                    onCommitted: if (!SendaHyprlandSettings.save("--idle-seconds", text.trim())) text = String(SendaHyprlandSettings.values.idleSeconds)
                }
            }
            SettingsRow {
                label: "Desenfocar pantalla de bloqueo"
                SettingsSwitch {
                    checkedValue: SendaHyprlandSettings.loaded && SendaHyprlandSettings.values.blur
                    enabled: SendaHyprlandSettings.loaded && !SendaHyprlandSettings.busy
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
