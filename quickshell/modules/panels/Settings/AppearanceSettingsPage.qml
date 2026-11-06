import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import qs.common
import qs.common.components.controls
import qs.services

// Appearance settings: the theme, the size of the interface text and the cursor.
Flickable {
    id: root

    readonly property int minPercent: 80
    readonly property int maxPercent: 150
    readonly property int stepPercent: 10
    readonly property int currentPercent: Math.round(Theme.fontScale * 100)

    contentHeight: column.implicitHeight
    clip: true

    function changeTo(percent) {
        const clamped = Math.max(root.minPercent, Math.min(root.maxPercent, percent));
        // 100% is stored as no value, so the file keeps only deliberate changes.
        ZendaSettings.save(
            { ZENDA_UI_FONT_SCALE: clamped === 100 ? "" : String(clamped) },
            "Tamaño de letra guardado"
        );
    }

    readonly property int currentRounding: Math.round(Theme.roundingScale * 100)

    function changeRounding(percent) {
        const clamped = Math.max(0, Math.min(100, Math.round(percent)));
        ZendaSettings.save(
            { ZENDA_UI_ROUNDING: clamped === 100 ? "" : String(clamped) },
            "Redondeo guardado"
        );
    }

    Component.onCompleted: ZendaTheme.refresh()

    // Cursor values live in the input service, with the same user overrides.
    function managed(field) { return ZendaInputSettings.user[field] !== undefined; }
    function modified_(field) {
        const saved = ZendaInputSettings.saved[field] || "";
        if (root.managed(field) || saved === "") return false;
        const fallback = ZendaInputSettings.defaults[field] || "";
        return isNaN(Number(saved)) ? saved !== fallback : Number(saved) !== Number(fallback === "" ? NaN : fallback);
    }
    function note(field, text) {
        const user = ZendaInputSettings.user[field];
        if (!user) return text;
        return "Gestionado por el usuario en " + user.file.split("/").pop();
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Tema"
                modified: Theme.currentTheme !== "zenda-ice"
                onResetRequested: ZendaTheme.apply("zenda-ice")
                description: ZendaTheme.lastError !== "" ? ZendaTheme.lastError
                    : `${Theme.currentTheme} · colores y fondo de todo el escritorio.`
                ZendaButton {
                    label: "Elegir tema"
                    enabled: !ZendaTheme.busy
                    // Same picker as the top bar, on the focused monitor.
                    onClicked: ZendaTheme.openPicker(Hyprland.focusedMonitor?.name ?? "")
                }
            }
        }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Tamaño de la letra"
                modified: root.currentPercent !== 100
                onResetRequested: root.changeTo(100)
                description: "Escala toda la interfaz entre 80 y 150 %."
                ZendaSlider {
                    value: root.currentPercent
                    enabled: ZendaSettings.configLoaded
                    onCommitted: value => root.changeTo(value)
                }
            }
        }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Redondeo de esquinas"
                modified: root.currentRounding !== 100
                onResetRequested: root.changeRounding(100)
                description: "Reduce el redondeo de cartas, grupos y controles."
                ZendaSlider {
                    from: 0; to: 100; stepSize: 10
                    suffix: " %"
                    value: root.currentRounding
                    enabled: ZendaSettings.configLoaded
                    // Previews while dragging; the value is saved on release.
                    onMoved: value => Theme.setRoundingScale(value)
                    onCommitted: value => root.changeRounding(value)
                }
            }
        }
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Tema de cursor"
                modified: root.modified_("cursorTheme")
                onResetRequested: ZendaInputSettings.set("cursor-theme", "")
                description: root.note("cursorTheme", "Se aplica al momento")
                ZendaSelect {
                    enabled: !root.managed("cursorTheme")
                    options: ZendaInputSettings.cursorThemes
                    value: ZendaInputSettings.current.cursorTheme || ""
                    onChosen: value => ZendaInputSettings.set("cursor-theme", value)
                }
            }
            ZendaRow {
                label: "Tamaño del cursor"
                modified: root.modified_("cursorSize")
                onResetRequested: ZendaInputSettings.set("cursor-size", "")
                description: root.note("cursorSize", "Se aplica al momento")
                ZendaSlider {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("cursorSize")
                    from: 16; to: 64; stepSize: 2
                    suffix: " px"
                    value: Number(ZendaInputSettings.current.cursorSize || 24)
                    onCommitted: value => ZendaInputSettings.set("cursor-size", Math.round(value))
                }
            }
        }
    }
}
