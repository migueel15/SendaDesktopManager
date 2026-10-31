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
    function editTheme(info, existing, duplicating) {
        pendingDelete = null;
        editor.setSource(Qt.resolvedUrl("ThemeEditor.qml"), {
            baseTheme: info, editing: existing && info.builtin === false, duplicating: duplicating === true
        });
    }
    function openPendingDuplicate() {
        if (!expanded || !SendaTheme.duplicatePending || !SendaTheme.active)
            return;
        SendaTheme.duplicatePending = false;
        editTheme(SendaTheme.active, false, true);
    }
    onExpandedChanged: {
        if (expanded) {
            showList();
            SendaTheme.refresh();
            Qt.callLater(() => content.forceActiveFocus());
            openPendingDuplicate();
        }
    }
    Connections {
        target: SendaTheme
        function onDuplicatePendingChanged() { root.openPendingDuplicate(); }
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
                color: Qt.rgba(Theme.colors.error.r, Theme.colors.error.g, Theme.colors.error.b, 0.14)
                border.width: 2
                border.color: Theme.colors.error
                ColumnLayout {
                    id: confirmation
                    anchors.fill: parent
                    anchors.margins: Theme.spacing.md
                    Text {
                        Layout.fillWidth: true
                        text: `¿Borrar el tema «${root.pendingDelete?.name ?? ""}»?`
                        font: Theme.font.title
                        color: Theme.colors.error
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Se eliminarán su carpeta y su imagen. No se puede deshacer."
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
                            destructive: true
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
                // The list steps back while a deletion waits for confirmation.
                enabled: root.pendingDelete === null
                opacity: enabled ? 1 : 0.35
                ScrollBar.vertical: ScrollBar {}
                delegate: ThemeCard {
                    required property var modelData
                    themeInfo: modelData
                    width: grid.cellWidth - Theme.spacing.sm
                    height: grid.cellHeight - Theme.spacing.sm
                    onEditRequested: info => root.editTheme(info, true)
                    onDuplicateRequested: info => root.editTheme(info, false, true)
                    onDeleteRequested: info => root.pendingDelete = info
                }
            }
        }
    }
    component ActionButton: Button {
        id: button
        property bool destructive: false
        font: Theme.font.body
        padding: Theme.spacing.sm
        background: Rectangle {
            radius: Theme.rounding.normal
            color: button.destructive ? (button.hovered ? Qt.lighter(Theme.colors.error, 1.1) : Theme.colors.error)
                : button.hovered ? Theme.colors.surfaceVariant : Theme.colors.surface
            opacity: button.enabled ? 1 : 0.5
            border.width: 1
            border.color: button.activeFocus ? Theme.colors.focus
                : button.destructive ? Theme.colors.error : Theme.colors.surfaceVariant
        }
        contentItem: Text {
            text: button.text
            font: button.font
            color: !button.enabled ? Theme.colors.overlay
                : button.destructive ? Theme.colors.base : Theme.colors.text
        }
    }
}
