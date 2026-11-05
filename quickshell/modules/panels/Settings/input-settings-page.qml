pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.components.controls
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    readonly property bool accelFlat: ZendaInputSettings.current.accelProfile === "flat"

    function managed(field) { return ZendaInputSettings.user[field] !== undefined; }
    // A saved value that differs from the default; the user's own never does.
    function modified_(field) {
        const saved = ZendaInputSettings.saved[field] || "";
        if (root.managed(field) || saved === "") return false;
        const fallback = ZendaInputSettings.defaults[field] || "";
        return isNaN(Number(saved)) ? saved !== fallback : Number(saved) !== Number(fallback === "" ? NaN : fallback);
    }
    // The notice exists only for fields the user's configuration defines.
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
                label: "Distribución de teclado"
                modified: root.modified_("layout")
                onResetRequested: { layoutField.text = ZendaInputSettings.defaults.layout || ""; ZendaInputSettings.set("layout", ""); }
                description: root.note("layout", "Código XKB; varias separadas por comas, p. ej. us,es")
                ZendaField {
                    id: layoutField
                    implicitWidth: Theme.scaled(160)
                    enabled: !root.managed("layout")
                    text: ZendaInputSettings.current.layout || ""
                    onCommitted: ZendaInputSettings.set("layout", text.trim())
                }
            }
        }

        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Velocidad del ratón"
                modified: root.modified_("sensitivity")
                onResetRequested: ZendaInputSettings.set("sensitivity", "")
                description: root.note("sensitivity", "50 % es la velocidad normal")
                ZendaSlider {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("sensitivity")
                    from: 0; to: 100; stepSize: 5
                    // Hyprland uses -1 to 1; the interface shows a percentage.
                    value: Math.round((Number(ZendaInputSettings.current.sensitivity || 0) + 1) * 50)
                    onCommitted: value => ZendaInputSettings.set("sensitivity", (value / 50 - 1).toFixed(2))
                }
            }
            ZendaRow {
                label: "Aceleración del ratón"
                modified: root.modified_("accelProfile")
                onResetRequested: ZendaInputSettings.set("accel-profile", "")
                description: root.note("accelProfile", root.accelFlat ? "Plana: el cursor recorre siempre lo mismo que la mano" : "Adaptativa: si mueves rápido, el cursor llega más lejos")
                ZendaSegments {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("accelProfile")
                    options: [{ value: "adaptive", label: "Adaptativa" }, { value: "flat", label: "Plana" }]
                    value: root.accelFlat ? "flat" : "adaptive"
                    onChosen: value => ZendaInputSettings.set("accel-profile", value)
                }
            }
            // Sketch of how far the cursor goes for each hand speed.
            Canvas {
                id: accelCurve
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.scaled(90)
                Accessible.ignored: true
                Connections {
                    target: root
                    function onAccelFlatChanged() { accelCurve.requestPaint(); }
                }
                onPaint: {
                    const ctx = getContext("2d");
                    const m = 14, w = width - 2 * m, h = height - 2 * m;
                    ctx.reset();
                    ctx.strokeStyle = Theme.colors.border;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(m, m); ctx.lineTo(m, m + h); ctx.lineTo(m + w, m + h);
                    ctx.stroke();
                    ctx.strokeStyle = Theme.colors.primary;
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    for (let i = 0; i <= 40; i++) {
                        const x = i / 40;
                        const y = root.accelFlat ? 0.5 * x : 0.2 * x + 0.8 * x * x;
                        if (i === 0) ctx.moveTo(m, m + h);
                        else ctx.lineTo(m + x * w, m + h - y * h);
                    }
                    ctx.stroke();
                    ctx.fillStyle = Theme.colors.overlay;
                    ctx.font = "11px sans-serif";
                    ctx.fillText("distancia del cursor", m + 4, m + 2);
                    ctx.textAlign = "right";
                    ctx.fillText("velocidad de la mano", m + w, m + h + 12);
                }
            }
            ZendaRow {
                label: "Foco con el ratón"
                modified: root.modified_("followMouse")
                onResetRequested: ZendaInputSettings.set("follow-mouse", "")
                description: root.note("followMouse", ["El foco no sigue al cursor", "La ventana bajo el cursor recibe el foco", "Cursor y teclado separados; el clic da el foco", "Cursor y teclado totalmente separados"][Number(ZendaInputSettings.current.followMouse || 1)] || "")
                ZendaSegments {
                    implicitWidth: Theme.scaled(260)
                    enabled: !root.managed("followMouse")
                    options: [{ value: "0", label: "No" }, { value: "1", label: "Sigue" }, { value: "2", label: "Clic" }, { value: "3", label: "Aparte" }]
                    value: ZendaInputSettings.current.followMouse || "1"
                    onChosen: value => ZendaInputSettings.set("follow-mouse", value)
                }
            }
        }

        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Tocar para hacer clic"
                modified: root.modified_("tapToClick")
                onResetRequested: ZendaInputSettings.set("tap-to-click", "")
                description: root.note("tapToClick", "En el touchpad")
                ZendaSwitch {
                    enabled: !root.managed("tapToClick")
                    checkedValue: ZendaInputSettings.current.tapToClick === "true"
                    onToggledValue: value => ZendaInputSettings.set("tap-to-click", value)
                }
            }
            ZendaRow {
                label: "Desplazamiento natural"
                modified: root.modified_("naturalScroll")
                onResetRequested: ZendaInputSettings.set("natural-scroll", "")
                description: root.note("naturalScroll", "En el touchpad")
                ZendaSwitch {
                    enabled: !root.managed("naturalScroll")
                    checkedValue: ZendaInputSettings.current.naturalScroll === "true"
                    onToggledValue: value => ZendaInputSettings.set("natural-scroll", value)
                }
            }
        }

        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Desactivar touchpad al escribir"
                modified: root.modified_("disableWhileTyping")
                onResetRequested: ZendaInputSettings.set("disable-while-typing", "")
                description: root.note("disableWhileTyping", "Evita toques accidentales con la palma")
                ZendaSwitch {
                    enabled: !root.managed("disableWhileTyping")
                    checkedValue: ZendaInputSettings.current.disableWhileTyping === "true"
                    onToggledValue: value => ZendaInputSettings.set("disable-while-typing", value)
                }
            }
            ZendaRow {
                label: "Velocidad de desplazamiento"
                modified: root.modified_("scrollFactor")
                onResetRequested: ZendaInputSettings.set("scroll-factor", "")
                description: root.note("scrollFactor", "En el touchpad; 100 % es lo normal")
                ZendaSlider {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("scrollFactor")
                    from: 10; to: 300; stepSize: 10
                    value: Math.round(Number(ZendaInputSettings.current.scrollFactor || 1) * 100)
                    onCommitted: value => ZendaInputSettings.set("scroll-factor", (value / 100).toFixed(2))
                }
            }
            ZendaRow {
                label: "Velocidad del touchpad"
                modified: root.modified_("touchpadSensitivity")
                onResetRequested: ZendaInputSettings.set("touchpad-sensitivity", "")
                description: root.note("touchpadSensitivity", "Sigue a la del ratón hasta que eliges una; 50 % es la normal")
                ZendaSlider {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("touchpadSensitivity")
                    from: 0; to: 100; stepSize: 5
                    value: Math.round((Number(ZendaInputSettings.current.touchpadSensitivity || 0) + 1) * 50)
                    onCommitted: value => ZendaInputSettings.set("touchpad-sensitivity", (value / 50 - 1).toFixed(2))
                }
            }
        }


        ZendaStatus {
            Layout.fillWidth: true
            error: true
            message: ZendaInputSettings.error
        }
    }
}
