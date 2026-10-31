import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import qs.services

Rectangle {
    id: root
    required property var themeInfo
    readonly property bool valid: themeInfo.valid === true
    readonly property bool selected: SendaTheme.active?.name === themeInfo.name
    signal editRequested(var info)
    signal duplicateRequested(var info)
    signal deleteRequested(var info)

    implicitHeight: Theme.scaled(220)
    radius: Theme.rounding.normal
    color: selected ? Theme.colors.selection : Theme.colors.surface
    border.width: 1
    border.color: selected ? Theme.colors.focus : Theme.colors.border

    // Declared before the layout so the action buttons receive clicks first.
    MouseArea {
        anchors.fill: parent
        enabled: root.valid && !SendaTheme.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: SendaTheme.apply(root.themeInfo.name)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.sm
        spacing: Theme.spacing.xs

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.scaled(84)
            color: Theme.colors.base
            clip: true
            opacity: root.valid ? 1 : 0.45
            Image {
                anchors.fill: parent
                source: root.themeInfo.wallpaper
                    ? "file://" + root.themeInfo.wallpaper.split("/").map(encodeURIComponent).join("/") : ""
                sourceSize: Qt.size(320, 180)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
        }
        Row {
            Layout.fillWidth: true
            height: Theme.spacing.sm
            opacity: root.valid ? 1 : 0.45
            Repeater {
                model: ["base", "background", "surface", "primary", "secondary", "accent", "success", "warning", "error"]
                Rectangle {
                    required property string modelData
                    width: parent.width / 9
                    height: Theme.spacing.sm
                    color: root.themeInfo.colors?.[modelData] ?? Theme.colors.surfaceVariant
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.themeInfo.name
            font: Theme.font.heading
            color: root.valid ? Theme.colors.text : Theme.colors.overlay
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.valid ? (root.selected ? "Activo" : "Pulsar para aplicar") : root.themeInfo.error
            font: Theme.font.caption
            color: root.valid ? Theme.colors.overlay : Theme.colors.error
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            CardButton {
                text: "Editar"
                font: Theme.font.caption
                visible: root.themeInfo.builtin === false
                enabled: !SendaTheme.busy
                onClicked: root.editRequested(root.themeInfo)
            }
            CardButton {
                text: "Duplicar"
                font: Theme.font.caption
                enabled: root.valid && !SendaTheme.busy
                onClicked: root.duplicateRequested(root.themeInfo)
            }
            CardButton {
                text: "Borrar"
                font: Theme.font.caption
                visible: root.themeInfo.builtin === false
                enabled: !SendaTheme.busy
                onClicked: root.deleteRequested(root.themeInfo)
            }
        }
    }
    component CardButton: Button {
        id: button
        padding: Theme.spacing.xs
        background: Rectangle {
            radius: Theme.rounding.small
            color: button.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface
            border.width: 1
            border.color: button.activeFocus ? Theme.colors.focus : Theme.colors.border
        }
        contentItem: Text {
            text: button.text
            font: button.font
            color: button.enabled ? Theme.colors.text : Theme.colors.overlay
        }
    }
}
