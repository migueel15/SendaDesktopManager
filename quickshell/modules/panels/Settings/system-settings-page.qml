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
            idleField.text = String(SendaHyprlandSettings.values.idleSeconds);
        }
    }

    // Check mark that fades in and out when its setting is saved. It always
    // takes its space, so the row does not move.
    component SavedMark: Text {
        id: mark
        property string flag: ""
        text: "\uf00c"
        color: Theme.colors.success
        font.family: Theme.iconFamily
        font.pixelSize: Theme.scaled(13)
        opacity: 0
        Accessible.ignored: true
        Connections {
            target: SendaHyprlandSettings
            function onSaved(flag) { if (flag === mark.flag) pulse.restart(); }
        }
        SequentialAnimation {
            id: pulse
            NumberAnimation { target: mark; property: "opacity"; to: 1; duration: 120 }
            PauseAnimation { duration: 900 }
            NumberAnimation { target: mark; property: "opacity"; to: 0; duration: 400 }
        }
    }

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
                label: "Tiempo de inactividad"
                description: "Segundos, de 0 a 86400. 0 desactiva el bloqueo automático."
                SavedMark { flag: "--idle-seconds" }
                SettingsField {
                    id: idleField
                    Layout.preferredWidth: 100
                    enabled: SendaHyprlandSettings.loaded
                    text: SendaHyprlandSettings.loaded ? String(SendaHyprlandSettings.values.idleSeconds) : ""
                    placeholder: "Segundos"
                    onCommitted: if (!SendaHyprlandSettings.save("--idle-seconds", text.trim())) text = String(SendaHyprlandSettings.values.idleSeconds)
                }
            }
            SettingsRow {
                label: "Desenfocar pantalla de bloqueo"
                SavedMark { flag: "--blur" }
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
