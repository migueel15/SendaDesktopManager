import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import qs.services
import qs.common.components.barextension as BarComponents

BarComponents.BarExtension {
    id: root
    required property bool onPickerScreen
    property real maximumHeight: 800
    property var pendingDelete: null
    readonly property bool editing: editor.source.toString() !== ""
    readonly property bool fileDialogOpen: editor.item?.fileDialogOpen ?? false
    readonly property real listHeight: Theme.scaled(560)
    expanded: onPickerScreen && SendaTheme.pickerOpen
    expandedHeight: Math.min(maximumHeight, editing
        ? (editor.item?.implicitHeight || listHeight) + Theme.spacing.lg * 2 : listHeight)
    resizeDuration: Theme.motion.slow
    autoHideOnPointerExit: false
    conflictGroup: "tray-popups"
    onCloseRequested: SendaTheme.closePicker()

    function showList() {
        editor.source = "";
        pendingDelete = null;
        content.forceActiveFocus();
    }
    function editTheme(info, existing) {
        pendingDelete = null;
        editor.setSource(Qt.resolvedUrl("ThemeEditor.qml"), {
            baseTheme: info, editing: existing && info.builtin === false
        });
    }
    onExpandedChanged: {
        if (expanded) {
            showList();
            SendaTheme.refresh();
            Qt.callLater(() => content.forceActiveFocus());
        }
    }

    FocusScope {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacing.lg
        Keys.onEscapePressed: event => {
            if (root.editing || root.pendingDelete) root.showList();
            else SendaTheme.closePicker();
            event.accepted = true;
        }

        Flickable {
            anchors.fill: parent
            visible: root.editing
            clip: true
            contentHeight: editor.item?.implicitHeight ?? 0
            ScrollBar.vertical: ScrollBar {}
            Loader {
                id: editor
                width: content.width
                onLoaded: item.forceActiveFocus()
            }
        }
        Connections {
            target: editor.item
            function onClosed() { root.showList(); }
            function onSaved(info) { root.showList(); }
        }

        ColumnLayout {
            anchors.fill: parent
            visible: !root.editing
            spacing: Theme.spacing.md
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Temas"
                    font: Theme.font.title
                    color: Theme.colors.text
                }
                ActionButton {
                    text: "Nuevo tema"
                    enabled: !!SendaTheme.active && !SendaTheme.busy
                    onClicked: root.editTheme(SendaTheme.active, false)
                }
                ActionButton {
                    text: "Cerrar"
                    onClicked: SendaTheme.closePicker()
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: SendaTheme.lastError
                font: Theme.font.caption
                color: Theme.colors.error
                wrapMode: Text.Wrap
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: confirmation.implicitHeight + Theme.spacing.md * 2
                visible: root.pendingDelete !== null
                radius: Theme.rounding.normal
                color: Theme.colors.surfaceRaised
                ColumnLayout {
                    id: confirmation
                    anchors.fill: parent
                    anchors.margins: Theme.spacing.md
                    Text {
                        Layout.fillWidth: true
                        text: `¿Borrar el tema «${root.pendingDelete?.name ?? ""}»?`
                        font: Theme.font.body
                        color: Theme.colors.text
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        ActionButton {
                            text: "Cancelar"
                            onClicked: root.pendingDelete = null
                        }
                        ActionButton {
                            text: "Borrar tema"
                            enabled: !SendaTheme.busy
                            onClicked: {
                                if (root.pendingDelete?.builtin === false)
                                    SendaTheme.remove(root.pendingDelete.name);
                                root.pendingDelete = null;
                            }
                        }
                    }
                }
            }
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width / Math.max(1, Math.floor(width / Theme.scaled(210)))
                cellHeight: Theme.scaled(220) + Theme.spacing.sm
                model: SendaTheme.themes
                ScrollBar.vertical: ScrollBar {}
                delegate: ThemeCard {
                    required property var modelData
                    themeInfo: modelData
                    width: grid.cellWidth - Theme.spacing.sm
                    height: grid.cellHeight - Theme.spacing.sm
                    onEditRequested: info => root.editTheme(info, true)
                    onDeleteRequested: info => root.pendingDelete = info
                }
            }
        }
    }
    component ActionButton: Button {
        id: button
        font: Theme.font.body
        padding: Theme.spacing.sm
        background: Rectangle {
            radius: Theme.rounding.normal
            color: button.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface
            border.width: 1
            border.color: button.activeFocus ? Theme.colors.focus : Theme.colors.surfaceVariant
        }
        contentItem: Text {
            text: button.text
            font: button.font
            color: button.enabled ? Theme.colors.text : Theme.colors.overlay
        }
    }
}
