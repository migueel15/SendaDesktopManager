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

    readonly property bool accelFlat: SendaInputSettings.current.accelProfile === "flat"

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
                description: root.note("sensitivity", "50 % es la velocidad normal")
                SettingsSlider {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("sensitivity")
                    from: 0; to: 100; stepSize: 5
                    // Hyprland uses -1 to 1; the interface shows a percentage.
                    value: Math.round((Number(SendaInputSettings.current.sensitivity || 0) + 1) * 50)
                    onCommitted: value => SendaInputSettings.set("sensitivity", (value / 50 - 1).toFixed(2))
                }
            }
            SettingsRow {
                label: "Aceleración del ratón"
                description: root.note("accelProfile", root.accelFlat ? "Plana: el cursor recorre siempre lo mismo que la mano" : "Adaptativa: si mueves rápido, el cursor llega más lejos")
                SettingsSegments {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("accelProfile")
                    options: [{ value: "adaptive", label: "Adaptativa" }, { value: "flat", label: "Plana" }]
                    value: root.accelFlat ? "flat" : "adaptive"
                    onChosen: value => SendaInputSettings.set("accel-profile", value)
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
            SettingsRow {
                label: "Foco con el ratón"
                description: root.note("followMouse", ["El foco no sigue al cursor", "La ventana bajo el cursor recibe el foco", "Cursor y teclado separados; el clic da el foco", "Cursor y teclado totalmente separados"][Number(SendaInputSettings.current.followMouse || 1)] || "")
                SettingsSegments {
                    implicitWidth: Theme.scaled(260)
                    enabled: !root.managed("followMouse")
                    options: [{ value: "0", label: "No" }, { value: "1", label: "Sigue" }, { value: "2", label: "Clic" }, { value: "3", label: "Aparte" }]
                    value: SendaInputSettings.current.followMouse || "1"
                    onChosen: value => SendaInputSettings.set("follow-mouse", value)
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
                label: "Desactivar touchpad al escribir"
                description: root.note("disableWhileTyping", "Evita toques accidentales con la palma")
                SettingsSwitch {
                    enabled: !root.managed("disableWhileTyping")
                    checkedValue: SendaInputSettings.current.disableWhileTyping === "true"
                    onToggledValue: value => SendaInputSettings.set("disable-while-typing", value)
                }
            }
            SettingsRow {
                label: "Velocidad de desplazamiento"
                description: root.note("scrollFactor", "En el touchpad; 100 % es lo normal")
                SettingsSlider {
                    implicitWidth: Theme.scaled(200)
                    enabled: !root.managed("scrollFactor")
                    from: 10; to: 300; stepSize: 10
                    value: Math.round(Number(SendaInputSettings.current.scrollFactor || 1) * 100)
                    onCommitted: value => SendaInputSettings.set("scroll-factor", (value / 100).toFixed(2))
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
