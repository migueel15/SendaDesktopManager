pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.components.controls
import qs.services

Flickable {
    id: root
    readonly property bool retainWhenHidden: appName !== "" || commandField.text !== "" || pathField.text !== ""
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
            ZendaStartupSettings.add("app", entry.name, root.shellCommand(entry.command));
            root.appName = "";
            return;
        }
        if (root.kind === "command") {
            if (commandField.text.trim() === "") return;
            ZendaStartupSettings.add("command", "", commandField.text.trim());
            commandField.text = "";
            return;
        }
        if (pathField.text.trim() === "") return;
        ZendaStartupSettings.add(root.kind, "", pathField.text.trim());
        pathField.text = "";
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        ZendaGroup {
            ZendaRow {
                label: "Tipo"
                description: "Qué quieres abrir al iniciar Hyprland"
                ZendaSegments {
                    implicitWidth: Theme.scaled(350)
                    Layout.fillWidth: false
                    value: root.kind
                    options: [{ label: "Aplicación", value: "app" }, { label: "Comando", value: "command" }, { label: "Script", value: "script" }, { label: "Archivo", value: "file" }]
                    onChosen: value => root.kind = value
                }
            }
            ZendaRow {
                separator: false
                label: "Añadir"
                description: root.kind === "app" ? "Aplicaciones instaladas" : root.kind === "command" ? "Comando completo con sus argumentos" : "Ruta absoluta o que empiece por ~/"
                ZendaSelect {
                    visible: root.kind === "app"
                    options: root.apps.map(app => app.name)
                    value: root.appName
                    placeholder: "Elegir aplicación"
                    searchable: true
                    searchPlaceholder: "Buscar aplicación…"
                    onChosen: value => root.appName = value
                }
                ZendaField {
                    id: commandField
                    visible: root.kind === "command"
                    implicitWidth: Theme.scaled(300)
                    placeholder: "openrgb --startminimized -p purple"
                    onAccepted: root.add()
                }
                ZendaField {
                    id: pathField
                    visible: root.kind === "script" || root.kind === "file"
                    implicitWidth: Theme.scaled(220)
                    placeholder: "~/scripts/inicio.sh"
                }
                ZendaButton {
                    label: "Añadir"
                    primary: true
                    onClicked: root.add()
                }
            }
        }

        ZendaGroup {
            visible: ZendaStartupSettings.entries.length > 0
            Repeater {
                model: ZendaStartupSettings.entries
                delegate: ZendaRow {
                    id: row
                    required property var modelData
                    required property int index
                    searchable: false
                    separator: index < ZendaStartupSettings.entries.length - 1
                    label: modelData.name
                    description: modelData.target
                    ZendaSwitch {
                        checkedValue: row.modelData.enabled
                        onToggledValue: value => ZendaStartupSettings.setEnabled(row.modelData.target, value)
                    }
                    ZendaButton {
                        label: "Eliminar"
                        onClicked: ZendaStartupSettings.remove(row.modelData.target)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: ZendaStartupSettings.entries.length === 0
            text: "Aún no hay aplicaciones de inicio gestionadas por Zenda."
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

        ZendaGroup {
            visible: ZendaStartupSettings.externalEntries.length > 0
            Repeater {
                model: ZendaStartupSettings.externalEntries
                delegate: ZendaRow {
                    required property var modelData
                    required property int index
                    searchable: false
                    separator: index < ZendaStartupSettings.externalEntries.length - 1
                    label: modelData.name
                    description: modelData.target
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: ZendaStartupSettings.externalNotice !== ""
            text: ZendaStartupSettings.externalNotice
            color: Theme.colors.overlay
            font: Theme.font.caption
            wrapMode: Text.WordWrap
        }
    }
}
