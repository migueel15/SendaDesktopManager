pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    property string kind: "app"
    property string appName: ""
    readonly property var apps: Array.from(DesktopEntries.applications.values)
        .filter(entry => !entry.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    function shellCommand(args) {
        return Array.from(args).map(arg => /^[\w@%+=:,.\/-]+$/.test(arg) ? arg : "'" + arg.replace(/'/g, "'\\''") + "'").join(" ");
    }
    function add() {
        if (root.kind === "app") {
            const entry = root.apps.find(app => app.name === root.appName);
            if (!entry) return;
            SendaStartupSettings.add("app", entry.name, root.shellCommand(entry.command));
            root.appName = "";
            return;
        }
        if (pathField.text.trim() === "") return;
        SendaStartupSettings.add(root.kind, "", pathField.text.trim());
        pathField.text = "";
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        SettingsGroup {
            SettingsRow {
                label: "Tipo"
                description: "Qué quieres abrir al iniciar Hyprland"
                SettingsSegments {
                    implicitWidth: Theme.scaled(260)
                    Layout.fillWidth: false
                    value: root.kind
                    options: [{ label: "Aplicación", value: "app" }, { label: "Script", value: "script" }, { label: "Archivo", value: "file" }]
                    onChosen: value => root.kind = value
                }
            }
            SettingsRow {
                separator: false
                label: "Añadir"
                description: root.kind === "app" ? "Aplicaciones instaladas" : "Ruta absoluta o que empiece por ~/"
                SettingsSelect {
                    visible: root.kind === "app"
                    options: root.apps.map(app => app.name)
                    value: root.appName
                    placeholder: "Elegir aplicación"
                    searchable: true
                    searchPlaceholder: "Buscar aplicación…"
                    onChosen: value => root.appName = value
                }
                SettingsField {
                    id: pathField
                    visible: root.kind !== "app"
                    implicitWidth: Theme.scaled(220)
                    placeholder: "~/scripts/inicio.sh"
                }
                SettingsButton {
                    label: "Añadir"
                    primary: true
                    onClicked: root.add()
                }
            }
        }

        SettingsGroup {
            visible: SendaStartupSettings.entries.length > 0
            Repeater {
                model: SendaStartupSettings.entries
                delegate: SettingsRow {
                    id: row
                    required property var modelData
                    required property int index
                    searchable: false
                    separator: index < SendaStartupSettings.entries.length - 1
                    label: modelData.name
                    description: modelData.target
                    SettingsSwitch {
                        checkedValue: row.modelData.enabled
                        onToggledValue: value => SendaStartupSettings.setEnabled(row.modelData.target, value)
                    }
                    SettingsButton {
                        label: "Eliminar"
                        onClicked: SendaStartupSettings.remove(row.modelData.target)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SendaStartupSettings.entries.length === 0
            text: "Aún no hay aplicaciones de inicio gestionadas por Senda."
            color: Theme.colors.overlay
            font: Theme.font.caption
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: "Configuradas en Hyprland · Solo lectura"
            color: Theme.colors.overlay
            font: Theme.font.caption
            wrapMode: Text.WordWrap
        }

        SettingsGroup {
            visible: SendaStartupSettings.externalEntries.length > 0
            Repeater {
                model: SendaStartupSettings.externalEntries
                delegate: SettingsRow {
                    required property var modelData
                    required property int index
                    searchable: false
                    separator: index < SendaStartupSettings.externalEntries.length - 1
                    label: modelData.name
                    description: modelData.target
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SendaStartupSettings.externalNotice !== ""
            text: SendaStartupSettings.externalNotice
            color: Theme.colors.overlay
            font: Theme.font.caption
            wrapMode: Text.WordWrap
        }
    }
}
