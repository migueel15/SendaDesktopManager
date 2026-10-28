pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services

FloatingWindow {
    id: root
    visible: ScreenshotService.editorPath !== ""
    title: "Editor de captura — Senda"
    implicitWidth: 960
    implicitHeight: 680
    color: Theme.colors.background

    function submit(save) {
        if (ScreenshotService.working || image.status !== Image.Ready) return;
        const sx = image.sourceSize.width / selection.width, sy = image.sourceSize.height / selection.height;
        const x = Math.floor(selection.selectionX * sx), y = Math.floor(selection.selectionY * sy);
        const right = Math.min(image.sourceSize.width, Math.ceil((selection.selectionX + selection.selectionWidth) * sx));
        const bottom = Math.min(image.sourceSize.height, Math.ceil((selection.selectionY + selection.selectionHeight) * sy));
        ScreenshotService.crop(ScreenshotService.editorPath, x, y, right - x, bottom - y, save, false);
    }

    onVisibleChanged: if (visible) selection.reset()
    // Intercept the window manager close so the service can reopen this window.
    onClosed: ScreenshotService.closeEditor()

    component ActionButton: Controls.Button {
        id: button
        property bool primary: false
        font: Theme.font.body
        padding: Theme.spacing.md
        contentItem: Text {
            text: button.text; font: button.font
            color: button.primary ? Theme.colors.base : Theme.colors.text
            horizontalAlignment: Text.AlignHCenter
        }
        background: Rectangle {
            radius: Theme.rounding.normal
            color: button.primary ? (button.hovered ? Theme.colors.secondary : Theme.colors.primary)
                : (button.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface)
            border.width: 1
            border.color: button.visualFocus ? Theme.colors.focus : Theme.colors.surfaceVariant
            opacity: button.enabled ? 1 : 0.5
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: Theme.spacing.lg
        spacing: Theme.spacing.md
        Text { text: "Editor de captura"; font: Theme.font.title; color: Theme.colors.text }
        Text { text: "Arrastra para recortar o ajusta las asas del rectángulo."; font: Theme.font.caption; color: Theme.colors.overlay }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: Theme.colors.base; border.width: 1; border.color: Theme.colors.border
            Item {
                id: viewport
                anchors.fill: parent; anchors.margins: Theme.spacing.md
                Image {
                    id: image
                    anchors.fill: parent
                    source: ScreenshotService.editorPath ? "file://" + encodeURI(ScreenshotService.editorPath) : ""
                    fillMode: Image.PreserveAspectFit
                    onStatusChanged: if (status === Image.Ready) selection.reset()
                }
                CropSelection {
                    id: selection
                    width: image.paintedWidth; height: image.paintedHeight
                    anchors.centerIn: parent
                    editable: true
                    enabled: !ScreenshotService.working
                    onWidthChanged: reset()
                    onHeightChanged: reset()
                }
            }
        }
        Text {
            Layout.fillWidth: true; Layout.preferredHeight: Theme.scaled(36)
            text: ScreenshotService.message
            font: Theme.font.caption; color: Theme.colors.overlay; wrapMode: Text.WrapAnywhere
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight; spacing: Theme.spacing.sm
            ActionButton { text: "Guardar"; primary: true; enabled: !ScreenshotService.working; onClicked: root.submit(true) }
            ActionButton { text: "Copiar"; enabled: !ScreenshotService.working; onClicked: root.submit(false) }
            ActionButton { text: "Cerrar"; enabled: !ScreenshotService.working; onClicked: ScreenshotService.closeEditor() }
        }
    }
}
