pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    property string selectedName: ""
    readonly property var displays: SendaDisplaySettings.displays
    readonly property var selected: displays.find(d => d.name === selectedName) ?? displays[0] ?? null
    readonly property bool editable: !!selected && selected.managedBy !== "user" && !SendaDisplaySettings.busy
    // Mirrored and disabled monitors take no place in the layout.
    readonly property var placed: displays.filter(d => d.enabled && root.mirrorName(d) === "")
    readonly property var modes: selected ? selected.modes.map(root.splitMode) : []
    readonly property var sizes: [...new Set(modes.map(m => m.size))]
    readonly property string currentSize: selected ? selected.width + "x" + selected.height : ""
    readonly property var rates: modes.filter(m => m.size === currentSize).map(m => m.rate)

    // Hyprland rounds fractional scales (1.67 becomes 1.66667), so compare with
    // two decimals. A scale from elsewhere is offered too, to show it selected.
    readonly property string currentScale: selected ? String(Math.round(selected.scale * 100) / 100) : ""
    readonly property var scales: {
        const common = ["1", "1.25", "1.5", "1.67", "1.75", "2"];
        return currentScale === "" || common.includes(currentScale) ? common
            : common.concat(currentScale).sort((a, b) => Number(a) - Number(b));
    }

    function mirrorName(d) { return d.mirrorOf && d.mirrorOf !== "none" ? d.mirrorOf : ""; }
    function splitMode(mode) {
        const parts = mode.split("@");
        return { size: parts[0], rate: parts[1] ?? "" };
    }
    function closestRate(size, rate) {
        const options = modes.filter(m => m.size === size).map(m => Number(m.rate));
        return options.reduce((a, b) => Math.abs(b - rate) < Math.abs(a - rate) ? b : a).toFixed(2);
    }
    function logicalWidth(d) { return Math.round((d.transform % 2 ? d.height : d.width) / d.scale); }
    function logicalHeight(d) { return Math.round((d.transform % 2 ? d.width : d.height) / d.scale); }
    function overlaps(a, b) {
        return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
    }
    // Closest free place that touches another monitor by a side.
    function snap(d, x, y) {
        const w = logicalWidth(d), h = logicalHeight(d);
        const others = placed.filter(o => o.name !== d.name)
            .map(o => ({ x: o.x, y: o.y, w: logicalWidth(o), h: logicalHeight(o) }));
        let best = null;
        for (const o of others) {
            const clampY = Math.max(o.y - h + 1, Math.min(y, o.y + o.h - 1));
            const clampX = Math.max(o.x - w + 1, Math.min(x, o.x + o.w - 1));
            for (const c of [{ x: o.x + o.w, y: clampY }, { x: o.x - w, y: clampY }, { x: clampX, y: o.y + o.h }, { x: clampX, y: o.y - h }]) {
                // Edges close to each other line up.
                if (Math.abs(c.y - o.y) < 80) c.y = o.y;
                if (Math.abs(c.x - o.x) < 80) c.x = o.x;
                if (others.some(r => overlaps({ x: c.x, y: c.y, w: w, h: h }, r))) continue;
                const distance = Math.hypot(c.x - x, c.y - y);
                if (!best || distance < best.distance) best = { x: c.x, y: c.y, distance: distance };
            }
        }
        return best ?? { x: x, y: y };
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: Theme.spacing.md

        Text {
            Layout.fillWidth: true
            visible: !SendaDisplaySettings.loaded
            text: "No se han podido cargar las pantallas."
            color: Theme.colors.overlay
            font: Theme.font.caption
        }

        // Arrangement. Drawn to scale, with monitors dropped against each other.
        Rectangle {
            id: canvas
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.scaled(220)
            visible: root.placed.length > 0
            color: Theme.colors.base
            border { width: 1; color: Theme.colors.border }
            radius: Theme.rounding.normal

            readonly property real minX: Math.min(...root.placed.map(d => d.x))
            readonly property real minY: Math.min(...root.placed.map(d => d.y))
            readonly property real spanX: Math.max(...root.placed.map(d => d.x + root.logicalWidth(d))) - minX
            readonly property real spanY: Math.max(...root.placed.map(d => d.y + root.logicalHeight(d))) - minY
            // Spare room so a monitor can be dropped on any side.
            readonly property real ratio: Math.min(width / (spanX * 1.6), height / (spanY * 1.6))
            readonly property real originX: (width - spanX * ratio) / 2
            readonly property real originY: (height - spanY * ratio) / 2

            Repeater {
                model: root.placed
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool locked: modelData.managedBy === "user"
                    readonly property bool current: root.selected && root.selected.name === modelData.name
                    x: canvas.originX + (modelData.x - canvas.minX) * canvas.ratio
                    y: canvas.originY + (modelData.y - canvas.minY) * canvas.ratio
                    width: root.logicalWidth(modelData) * canvas.ratio
                    height: root.logicalHeight(modelData) * canvas.ratio
                    radius: Theme.rounding.small
                    color: tile.current ? Theme.colors.selection : Theme.colors.surfaceVariant
                    border { width: tile.current ? 2 : 1; color: tile.current ? Theme.colors.primary : Theme.colors.border }
                    z: drag.drag.active ? 1 : 0

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacing.sm
                        horizontalAlignment: Text.AlignHCenter
                        text: (tile.locked ? " " : "") + tile.modelData.name
                        color: Theme.colors.text
                        font: Theme.font.caption
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        cursorShape: tile.locked ? Qt.PointingHandCursor : Qt.SizeAllCursor
                        drag.target: tile.locked || SendaDisplaySettings.busy ? null : tile
                        onPressed: root.selectedName = tile.modelData.name
                        onReleased: {
                            if (tile.locked) return;
                            const d = tile.modelData;
                            const x = Math.round((tile.x - canvas.originX) / canvas.ratio + canvas.minX);
                            const y = Math.round((tile.y - canvas.originY) / canvas.ratio + canvas.minY);
                            const place = root.snap(d, x, y);
                            tile.x = Qt.binding(() => canvas.originX + (tile.modelData.x - canvas.minX) * canvas.ratio);
                            tile.y = Qt.binding(() => canvas.originY + (tile.modelData.y - canvas.minY) * canvas.ratio);
                            if (place.x !== d.x || place.y !== d.y)
                                SendaDisplaySettings.set(d.name, "--position", place.x + "x" + place.y);
                        }
                    }
                }
            }
        }

        // A change that may have left a screen unusable reverts by itself.
        SettingsGroup {
            visible: SendaDisplaySettings.confirmLeft > 0
            SettingsRow {
                separator: false
                label: "¿Mantener estos cambios?"
                description: "Se desharán en " + SendaDisplaySettings.confirmLeft + " s."
                SettingsButton { label: "Deshacer"; onClicked: SendaDisplaySettings.undo() }
                SettingsButton { label: "Mantener"; primary: true; onClicked: SendaDisplaySettings.keep() }
            }
        }

        SettingsGroup {
            visible: !!root.selected
            SettingsRow {
                separator: false
                label: "Pantalla"
                description: root.selected ? root.selected.description : ""
                SettingsSegments {
                    options: root.displays.map(d => ({ label: d.name, value: d.name }))
                    value: root.selected ? root.selected.name : ""
                    onChosen: value => root.selectedName = value
                }
            }
            SettingsRow {
                label: "Encendida"
                SettingsSwitch {
                    enabled: root.editable
                    checkedValue: !!root.selected && root.selected.enabled
                    Accessible.name: "Encendida"
                    onToggledValue: value => SendaDisplaySettings.setGuarded(root.selected.name, "--enabled", value)
                }
            }
            SettingsRow {
                label: "Resolución"
                SettingsSelect {
                    enabled: root.editable
                    options: root.sizes
                    value: root.currentSize
                    onChosen: value => SendaDisplaySettings.setGuarded(root.selected.name, "--mode", value + "@" + root.closestRate(value, root.selected.refreshRate))
                }
            }
            SettingsRow {
                label: "Frecuencia"
                SettingsSelect {
                    enabled: root.editable
                    options: root.rates.map(rate => rate + " Hz")
                    value: root.selected ? root.closestRate(root.currentSize, root.selected.refreshRate) + " Hz" : ""
                    onChosen: value => SendaDisplaySettings.setGuarded(root.selected.name, "--mode", root.currentSize + "@" + value.replace(" Hz", ""))
                }
            }
            SettingsRow {
                label: "Escala"
                SettingsSegments {
                    enabled: root.editable
                    options: root.scales.map(v => ({ label: Math.round(Number(v) * 100) + " %", value: v }))
                    value: root.currentScale
                    onChosen: value => SendaDisplaySettings.setGuarded(root.selected.name, "--scale", value)
                }
            }
            SettingsRow {
                label: "Rotación"
                SettingsSegments {
                    enabled: root.editable
                    options: ["0", "1", "2", "3"].map(v => ({ label: Number(v) * 90 + "°", value: v }))
                    value: root.selected ? String(root.selected.transform) : ""
                    onChosen: value => SendaDisplaySettings.setGuarded(root.selected.name, "--transform", value)
                }
            }
            SettingsRow {
                visible: root.displays.length > 1
                label: "Duplicar"
                description: "Muestra aquí lo mismo que en otra pantalla."
                SettingsSegments {
                    enabled: root.editable
                    options: [{ label: "No", value: "none" }].concat(root.displays
                        .filter(d => root.selected && d.name !== root.selected.name && d.enabled && root.mirrorName(d) === "")
                        .map(d => ({ label: d.name, value: d.name })))
                    value: root.selected ? (root.mirrorName(root.selected) || "none") : ""
                    onChosen: value => SendaDisplaySettings.setGuarded(root.selected.name, "--mirror", value)
                }
            }
            SettingsRow {
                visible: !!root.selected && root.selected.managedBy === "senda"
                label: "Restablecer"
                description: "Quita los ajustes de Senda de esta pantalla."
                SettingsButton {
                    label: "Restablecer"
                    enabled: root.editable
                    onClicked: SendaDisplaySettings.run(["reset", root.selected.name])
                }
            }
        }

        SettingsButton {
            visible: SendaDisplaySettings.canUndo && SendaDisplaySettings.confirmLeft === 0
            enabled: !SendaDisplaySettings.busy
            label: "Deshacer el último cambio"
            onClicked: SendaDisplaySettings.undo()
        }

        // Only exists for those who define monitors in their own configuration.
        SettingsGroup {
            visible: SendaDisplaySettings.hasUserManaged
            SettingsRow {
                separator: false
                label: "Gestionado por tu configuración"
                description: "Senda no modifica estas pantallas. Cámbialas en tu configuración de Hyprland."
            }
            Repeater {
                model: root.displays.filter(d => d.managedBy === "user")
                delegate: SettingsRow {
                    required property var modelData
                    label: modelData.name
                    description: modelData.source
                }
            }
        }
    }
}
