import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Update settings: the installed version, the newer one when there is one, and
// the buttons to check again or update. When there is an update, the
// changelog lists what it brings, grouped by kind.
Flickable {
    id: root

    contentHeight: column.implicitHeight
    clip: true

    ColumnLayout {
        id: column
        width: root.width
        spacing: 12

        SettingsGroup {

            SettingsRow {
                separator: false
                label: ZendaUpdate.available
                    ? `${ZendaUpdate.current} → ${ZendaUpdate.latest}`
                    : `Versión ${ZendaUpdate.current || "sin comprobar"}`
                description: ZendaUpdate.message
                SettingsButton {
                    label: "Comprobar"
                    enabled: !ZendaUpdate.busy && !ZendaUpdate.installing
                    onClicked: ZendaUpdate.check()
                }
                SettingsButton {
                    label: ZendaUpdate.installing ? "Actualizando y reiniciando…" : "Actualizar"
                    primary: true
                    busy: ZendaUpdate.installing
                    enabled: ZendaUpdate.available && !ZendaUpdate.installing
                    onClicked: ZendaUpdate.install()
                }
            }
        }

        SettingsGroup {
            visible: ZendaUpdate.available && ZendaUpdate.changes.length > 0

            Text {
                Layout.fillWidth: true
                text: `Novedades de ${ZendaUpdate.latest}`
                color: Theme.colors.text
                font: Theme.font.title
            }

            Repeater {
                model: [
                    { type: "feat", title: "Nuevo" },
                    { type: "fix", title: "Correcciones" },
                    { type: "perf", title: "Rendimiento" }
                ]

                ColumnLayout {
                    id: section
                    required property var modelData
                    readonly property var items: ZendaUpdate.changes.filter(change => change.type === section.modelData.type)
                    Layout.fillWidth: true
                    visible: items.length > 0
                    spacing: Theme.spacing.xs

                    Text {
                        text: section.modelData.title
                        color: Theme.colors.primary
                        font: Theme.font.body
                    }

                    Repeater {
                        model: section.items

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.spacing.sm

                            Text {
                                Layout.alignment: Qt.AlignTop
                                text: "•"
                                color: Theme.colors.overlay
                                font: Theme.font.body
                            }
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                text: (modelData.scope ? modelData.scope + ": " : "")
                                    + modelData.summary.charAt(0).toUpperCase() + modelData.summary.slice(1)
                                color: Theme.colors.textMuted
                                font: Theme.font.body
                            }
                        }
                    }
                }
            }
        }
    }
}
