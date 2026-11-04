import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.common

// Debug-only window that shows design variants of Zenda controls, all built
// from the current theme palette, to choose the new look of the interface.
FloatingWindow {
    id: root
    title: "Zenda design gallery"
    visible: Debug.gallery
    implicitWidth: 980
    implicitHeight: 760
    color: Theme.colors.base

    // Shared demo state so every variant reacts to the same toggle.
    property bool demoOn: true
    property real demoValue: 0.6

    component VariantTitle: Text {
        color: Theme.colors.textMuted
        font: Theme.font.label
    }

    component Section: ColumnLayout {
        property string title
        default property alias items: grid.data
        Layout.fillWidth: true
        spacing: Theme.spacing.md
        Text { text: parent.title; color: Theme.colors.text; font: Theme.font.title }
        GridLayout { id: grid; columns: 3; columnSpacing: Theme.spacing.lg; rowSpacing: Theme.spacing.lg; Layout.fillWidth: true }
    }

    // A labelled box that holds one variant.
    component Variant: ColumnLayout {
        property string name
        default property alias content: holder.data
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: Theme.spacing.sm
        VariantTitle { text: parent.name }
        Item { id: holder; Layout.fillWidth: true; implicitHeight: childrenRect.height }
    }

    // ---- Switch variants -------------------------------------------------
    component SwitchA: Rectangle {   // current style
        property bool on: root.demoOn
        width: 34; height: 18; radius: height / 2
        color: on ? Theme.colors.primary : Theme.colors.surfaceVariant
        border { width: 1; color: Theme.colors.border }
        Rectangle {
            x: parent.on ? parent.width - width - 3 : 3; y: 3
            width: parent.height - 6; height: width; radius: width / 2
            color: parent.on ? Theme.colors.base : Theme.colors.text
            Behavior on x { NumberAnimation { duration: Theme.motion.fast; easing.type: Theme.motion.easing } }
        }
        MouseArea { anchors.fill: parent; onClicked: root.demoOn = !root.demoOn }
    }

    component SwitchB: Rectangle {   // tonal, larger, spring thumb that grows
        property bool on: root.demoOn
        width: 46; height: 26; radius: height / 2
        color: on ? Theme.colors.primary : Theme.colors.surfaceVariant
        Behavior on color { ColorAnimation { duration: Theme.motion.normal } }
        Rectangle {
            id: thumbB
            readonly property real size: parent.on ? 18 : 12
            x: parent.on ? parent.width - size - 4 : 7
            anchors.verticalCenter: parent.verticalCenter
            width: size; height: size; radius: size / 2
            color: parent.on ? Theme.colors.base : Theme.colors.overlay
            Behavior on x { SpringAnimation { spring: 4; damping: 0.28 } }
            Behavior on width { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack } }
        }
        MouseArea { anchors.fill: parent; onClicked: root.demoOn = !root.demoOn }
    }

    component SwitchC: Rectangle {   // outlined, square-ish, accent glow
        property bool on: root.demoOn
        width: 40; height: 22; radius: Theme.rounding.small
        color: on ? Theme.colors.selection : "transparent"
        border { width: 1.5; color: on ? Theme.colors.primary : Theme.colors.surfaceRaisedBorder }
        Behavior on color { ColorAnimation { duration: Theme.motion.normal } }
        Rectangle {
            x: parent.on ? parent.width - width - 4 : 4; anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 4
            color: parent.on ? Theme.colors.primary : Theme.colors.overlay
            Behavior on x { NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutQuint } }
        }
        MouseArea { anchors.fill: parent; onClicked: root.demoOn = !root.demoOn }
    }

    // ---- Card variants ---------------------------------------------------
    component CardContent: ColumnLayout {
        spacing: Theme.spacing.sm
        Text { text: "Animaciones"; color: Theme.colors.text; font: Theme.font.heading }
        Text { text: "Suaviza las transiciones de los paneles"; color: Theme.colors.textMuted; font: Theme.font.caption }
    }

    component CardA: Rectangle {     // current: surface + 1px border
        width: parent.width; height: 84; radius: Theme.rounding.normal
        color: Theme.colors.surface; border { width: 1; color: Theme.colors.border }
        CardContent { anchors { fill: parent; margins: Theme.spacing.md } }
    }

    component CardB: Rectangle {     // tonal, no border, large radius, hover lift
        id: cardB
        width: parent.width; height: 84; radius: 20
        color: hover.hovered ? Theme.colors.surfaceVariant : Theme.colors.surfaceRaised
        scale: tap.pressed ? 0.97 : 1
        Behavior on color { ColorAnimation { duration: Theme.motion.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutBack } }
        HoverHandler { id: hover }
        TapHandler { id: tap }
        CardContent { anchors { fill: parent; margins: Theme.spacing.lg } }
    }

    component CardC: Rectangle {     // accent stripe + gradient tint
        width: parent.width; height: 84; radius: Theme.rounding.large
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.colors.accentDeep }
            GradientStop { position: 1; color: Theme.colors.surface }
        }
        border { width: 1; color: hoverC.hovered ? Theme.colors.primary : Theme.colors.border }
        Behavior on border.color { ColorAnimation { duration: Theme.motion.normal } }
        HoverHandler { id: hoverC }
        Rectangle { x: 0; y: 14; width: 3; height: parent.height - 28; radius: 2; color: Theme.colors.primary }
        CardContent { anchors { fill: parent; margins: Theme.spacing.md; leftMargin: Theme.spacing.lg } }
    }

    // ---- Button variants -------------------------------------------------
    component ButtonA: Rectangle {   // current-like: flat outlined
        width: 120; height: 32; radius: Theme.rounding.small
        color: ha.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface
        border { width: 1; color: Theme.colors.border }
        HoverHandler { id: ha }
        Text { anchors.centerIn: parent; text: "Aplicar"; color: Theme.colors.text; font: Theme.font.body }
    }

    component ButtonB: Rectangle {   // filled pill, press squash
        width: 120; height: 36; radius: height / 2
        color: Theme.colors.primary
        scale: tb.pressed ? 0.94 : (hb.hovered ? 1.03 : 1)
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.3 } }
        HoverHandler { id: hb }
        TapHandler { id: tb }
        Text { anchors.centerIn: parent; text: "Aplicar"; color: Theme.colors.base; font: Theme.font.heading }
    }

    component ButtonC: Rectangle {   // tonal with ripple
        id: btnC
        width: 120; height: 34; radius: Theme.rounding.normal; clip: true
        color: Theme.colors.selection
        Rectangle {
            id: ripple
            width: 0; height: width; radius: width / 2; opacity: 0
            color: Theme.colors.primary
            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: ripple; property: "width"; from: 0; to: btnC.width * 2.2; duration: 420; easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; from: 0.35; to: 0; duration: 420 }
            }
        }
        TapHandler {
            onTapped: (p) => { ripple.x = p.position.x - btnC.width * 1.1; ripple.y = p.position.y - btnC.width * 1.1; rippleAnim.restart() }
        }
        Text { anchors.centerIn: parent; text: "Aplicar"; color: Theme.colors.secondary; font: Theme.font.heading }
    }

    // ---- Slider variants -------------------------------------------------
    component SliderBase: Item {
        id: s
        property real value: root.demoValue
        property real trackHeight: 4
        property color fill: Theme.colors.primary
        property color track: Theme.colors.surfaceVariant
        property Component handle
        width: parent.width; height: 28
        Rectangle { id: tr; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: s.trackHeight; radius: height / 2; color: s.track
            Rectangle { width: parent.width * s.value; height: parent.height; radius: parent.radius; color: s.fill } }
        Loader { sourceComponent: s.handle; x: s.width * s.value - width / 2; anchors.verticalCenter: parent.verticalCenter }
        MouseArea {
            anchors.fill: parent
            function set(m) { root.demoValue = Math.max(0, Math.min(1, m.x / width)) }
            onPressed: (m) => set(m); onPositionChanged: (m) => set(m)
        }
    }

    // ---- Layout ----------------------------------------------------------
    Flickable {
        anchors { fill: parent; margins: Theme.spacing.xl }
        contentHeight: column.implicitHeight
        clip: true
        ColumnLayout {
            id: column
            width: parent.width
            spacing: Theme.spacing.xl

            Text { text: "Galería de diseño · Zenda"; color: Theme.colors.white; font: Theme.font.display }

            Section {
                title: "Switches"
                Variant { name: "A · actual"; SwitchA {} }
                Variant { name: "B · tonal + muelle"; SwitchB {} }
                Variant { name: "C · contorno + cuadrado"; SwitchC {} }
            }
            Section {
                title: "Cards"
                Variant { name: "A · actual"; CardA {} }
                Variant { name: "B · tonal, radio grande, hover/press"; CardB {} }
                Variant { name: "C · degradado + franja acento"; CardC {} }
            }
            Section {
                title: "Botones"
                Variant { name: "A · plano contorno"; ButtonA {} }
                Variant { name: "B · píldora rellena + muelle"; ButtonB {} }
                Variant { name: "C · tonal + ripple"; ButtonC {} }
            }
            Section {
                title: "Sliders"
                Variant { name: "A · fino + punto"; SliderBase {
                    handle: Rectangle { width: 14; height: 14; radius: 7; color: Theme.colors.text } } }
                Variant { name: "B · grueso tonal"; SliderBase {
                    trackHeight: 14; track: Theme.colors.surfaceRaised
                    handle: Rectangle { width: 4; height: 22; radius: 2; color: Theme.colors.white } } }
                Variant { name: "C · acento + píldora"; SliderBase {
                    trackHeight: 6; fill: Theme.colors.accent
                    handle: Rectangle { width: 22; height: 14; radius: 7; color: Theme.colors.primary; border { width: 2; color: Theme.colors.base } } } }
            }
        }
    }
}
