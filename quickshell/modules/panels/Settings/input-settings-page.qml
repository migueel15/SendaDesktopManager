pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.common
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    function managed(field) { return SendaInputSettings.user[field] !== undefined; }
    // The notice exists only for fields the user's configuration defines.
    function note(field, text) {
        const user = SendaInputSettings.user[field];
        if (!user) return text;
        return "Gestionado por el usuario en " + user.file.split("/").pop();
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Distribución de teclado"
                description: root.note("layout", "Código XKB; varias separadas por comas, p. ej. us,es")
                SettingsField {
                    id: layoutField
                    implicitWidth: Theme.scaled(160)
                    enabled: !root.managed("layout")
                    text: SendaInputSettings.current.layout || ""
                    onCommitted: SendaInputSettings.set("layout", text.trim())
                }
            }
        }

        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Velocidad del ratón"
                description: root.note("sensitivity", "De -1 (lenta) a 1 (rápida)")
                SettingsSlider {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("sensitivity")
                    from: -1; to: 1; stepSize: 0.1
                    value: Number(SendaInputSettings.current.sensitivity || 0)
                    onCommitted: value => SendaInputSettings.set("sensitivity", value.toFixed(1))
                }
            }
        }

        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Tocar para hacer clic"
                description: root.note("tapToClick", "En el touchpad")
                SettingsSwitch {
                    enabled: !root.managed("tapToClick")
                    checkedValue: SendaInputSettings.current.tapToClick === "true"
                    onToggledValue: value => SendaInputSettings.set("tap-to-click", value)
                }
            }
            SettingsRow {
                label: "Desplazamiento natural"
                description: root.note("naturalScroll", "En el touchpad")
                SettingsSwitch {
                    enabled: !root.managed("naturalScroll")
                    checkedValue: SendaInputSettings.current.naturalScroll === "true"
                    onToggledValue: value => SendaInputSettings.set("natural-scroll", value)
                }
            }
        }

        SettingsGroup {
            SettingsRow {
                separator: false
                label: "Tema de cursor"
                description: root.note("cursorTheme", "Se aplica al momento")
                Controls.ComboBox {
                    implicitWidth: Theme.scaled(220)
                    enabled: !root.managed("cursorTheme")
                    model: SendaInputSettings.cursorThemes
                    currentIndex: SendaInputSettings.cursorThemes.indexOf(SendaInputSettings.current.cursorTheme)
                    displayText: currentIndex >= 0 ? currentText : (SendaInputSettings.current.cursorTheme || "Sin definir")
                    onActivated: index => SendaInputSettings.set("cursor-theme", SendaInputSettings.cursorThemes[index])
                }
            }
        }

        SettingsStatus {
            Layout.fillWidth: true
            error: true
            message: SendaInputSettings.error
        }
    }
}
