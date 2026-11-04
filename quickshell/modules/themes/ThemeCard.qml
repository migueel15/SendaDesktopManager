import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.common
import qs.common.components.controls
import qs.services

// Material 3 style theme card: rounded wallpaper preview, palette swatches,
// name and state, and icon actions. The active theme gets a tonal fill, a
// primary outline and a check badge.
Rectangle {
    id: root
    required property var themeInfo
    readonly property bool valid: themeInfo.valid === true
    readonly property bool selected: ZendaTheme.active?.name === themeInfo.name
    readonly property bool custom: themeInfo.builtin === false
    signal editRequested(var info)
    signal duplicateRequested(var info)
    signal deleteRequested(var info)

    implicitHeight: Theme.scaled(184)
    radius: Theme.card.radius
    color: selected ? Theme.colors.selection : hover.hovered && valid ? Theme.card.hoverFill : Theme.card.fill
    border.width: selected ? 2 : 0
    border.color: Theme.colors.primary
    scale: tap.pressed ? 0.98 : 1
    Behavior on color { ColorAnimation { duration: Theme.motion.normal } }
    Behavior on scale { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutBack } }

    HoverHandler { id: hover; cursorShape: root.valid ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler {
        id: tap
        enabled: root.valid && !ZendaTheme.busy
        onTapped: ZendaTheme.apply(root.themeInfo.name)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.sm
        spacing: Theme.spacing.sm

        ClippingRectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.card.radius - Theme.spacing.sm
            color: Theme.colors.base
            opacity: root.valid ? 1 : 0.45

            Image {
                anchors.fill: parent
                source: root.themeInfo.wallpaper
                    ? "file://" + root.themeInfo.wallpaper.split("/").map(encodeURIComponent).join("/") : ""
                sourceSize: Qt.size(320, 180)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }

            // Check badge on the active theme.
            Rectangle {
                visible: root.selected
                anchors { top: parent.top; right: parent.right; margins: Theme.spacing.sm }
                width: Theme.scaled(24); height: width; radius: width / 2
                color: Theme.colors.primary
                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Theme.colors.base
                    font.family: Theme.iconFamily
                    font.pixelSize: Theme.scaled(11)
                }
            }
        }

        // Palette as overlapping swatches.
        Row {
            Layout.leftMargin: Theme.spacing.xs
            spacing: -Theme.scaled(4)
            opacity: root.valid ? 1 : 0.45
            Repeater {
                model: ["base", "surface", "primary", "secondary", "accent", "success", "warning", "error"]
                Rectangle {
                    required property string modelData
                    width: Theme.scaled(16); height: width; radius: width / 2
                    color: root.themeInfo.colors?.[modelData] ?? Theme.colors.surfaceVariant
                    border.width: 2
                    border.color: root.color
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacing.xs
            spacing: Theme.spacing.xxs

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: root.themeInfo.name
                    font: Theme.font.heading
                    color: !root.valid ? Theme.colors.overlay : root.selected ? Theme.colors.primary : Theme.colors.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.valid ? (root.selected ? "Activo" : root.custom ? "Personalizado" : "Incluido") : root.themeInfo.error
                    font: Theme.font.caption
                    color: root.valid ? Theme.colors.overlay : Theme.colors.error
                    elide: Text.ElideRight
                }
            }

            ZendaIconButton {
                size: Theme.scaled(28)
                visible: root.custom
                enabled: !ZendaTheme.busy
                icon: ""
                accessibleLabel: "Editar tema"
                onClicked: root.editRequested(root.themeInfo)
            }
            ZendaIconButton {
                size: Theme.scaled(28)
                enabled: root.valid && !ZendaTheme.busy
                icon: ""
                accessibleLabel: "Duplicar tema"
                onClicked: root.duplicateRequested(root.themeInfo)
            }
            ZendaIconButton {
                size: Theme.scaled(28)
                visible: root.custom
                enabled: !ZendaTheme.busy
                icon: ""
                iconColor: Theme.colors.error
                accessibleLabel: "Borrar tema"
                onClicked: root.deleteRequested(root.themeInfo)
            }
        }
    }
}
