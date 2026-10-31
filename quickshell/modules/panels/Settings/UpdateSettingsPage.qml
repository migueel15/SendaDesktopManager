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
                label: SendaUpdate.available
                    ? `${SendaUpdate.current} → ${SendaUpdate.latest}`
                    : `Versión ${SendaUpdate.current || "sin comprobar"}`
                description: SendaUpdate.message
                SettingsButton {
                    label: "Comprobar"
                    enabled: !SendaUpdate.busy && !SendaUpdate.installing
                    onClicked: SendaUpdate.check()
                }
                SettingsButton {
                    label: SendaUpdate.installing ? "Actualizando y reiniciando…" : "Actualizar"
                    primary: true
                    busy: SendaUpdate.installing
                    enabled: SendaUpdate.available && !SendaUpdate.installing
                    onClicked: SendaUpdate.install()
                }
            }
        }

        SettingsGroup {
            visible: SendaUpdate.available && SendaUpdate.changes.length > 0

            Text {
                Layout.fillWidth: true
                text: `Novedades de ${SendaUpdate.latest}`
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
                    readonly property var items: SendaUpdate.changes.filter(change => change.type === section.modelData.type)
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
