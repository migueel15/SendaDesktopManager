import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import qs.common.components.controls
import qs.services
import qs.common.components.barextension as BarComponents

BarComponents.BarExtension {
    id: root
    property bool viewReady: false
    required property bool onPickerScreen
    property real maximumHeight: 800
    property var pendingDelete: null
    readonly property bool editing: editor.source.toString() !== ""
    // Fits the grid rows, up to three, so the panel has no empty space.
    readonly property int columns: Math.max(1, Math.floor((width - 2 * cornerRadius - Theme.spacing.lg * 2) / Theme.scaled(210)))
    readonly property int rows: Math.max(1, Math.ceil(ZendaTheme.themes.length / columns))
    readonly property real cellHeight: Theme.scaled(184) + Theme.spacing.md
    readonly property real listHeight: Theme.spacing.lg * 2 + Theme.scaled(40) + Theme.spacing.md
        + (pendingDelete ? Theme.scaled(130) : 0) + (ZendaTheme.lastError !== "" ? Theme.scaled(24) : 0)
        + Math.min(3, rows) * cellHeight - Theme.spacing.md
    expanded: onPickerScreen && ZendaTheme.pickerOpen
    expandedHeight: Math.min(maximumHeight, editing
        ? (editor.item?.implicitHeight || listHeight) + Theme.spacing.lg * 2 : listHeight)
    resizeDuration: Theme.motion.slow
    autoHideOnPointerExit: false
    conflictGroup: "tray-popups"
    onCloseRequested: ZendaTheme.closePicker()

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
        if (!expanded || !ZendaTheme.duplicatePending || !ZendaTheme.active)
            return;
        ZendaTheme.duplicatePending = false;
        editTheme(ZendaTheme.active, false, true);
    }
    function prepareOpen() {
        if (!root.viewReady) return;
        if (expanded) {
            if (!editing) showList();
            ZendaTheme.refresh();
            Qt.callLater(() => content.forceActiveFocus());
            openPendingDuplicate();
        }
    }
    onExpandedChanged: prepareOpen()
    Component.onCompleted: {
        root.viewReady = true;
        prepareOpen();
    }
    Connections {
        target: ZendaTheme
        function onDuplicatePendingChanged() { root.openPendingDuplicate(); }
    }

    FocusScope {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacing.lg
        Keys.onEscapePressed: event => {
            if (root.editing || root.pendingDelete) root.showList();
            else ZendaTheme.closePicker();
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
                spacing: Theme.spacing.sm
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: "Temas"
                        font.family: Theme.textFamily
                        font.pixelSize: Theme.scaled(20)
                        font.weight: Font.DemiBold
                        color: Theme.colors.text
                    }
                    Text {
                        text: ZendaTheme.themes.length === 1 ? "1 tema" : `${ZendaTheme.themes.length} temas`
                        font: Theme.font.caption
                        color: Theme.colors.overlay
                    }
                }
                Item { Layout.fillWidth: true }
                ZendaButton {
                    label: "Nuevo tema"
                    primary: true
                    enabled: !!ZendaTheme.active && !ZendaTheme.busy
                    onClicked: root.editTheme(ZendaTheme.active, false)
                }
                ZendaIconButton {
                    icon: "\uf00d"
                    accessibleLabel: "Cerrar"
                    onClicked: ZendaTheme.closePicker()
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: ZendaTheme.lastError
                font: Theme.font.caption
                color: Theme.colors.error
                wrapMode: Text.Wrap
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: confirmation.implicitHeight + Theme.spacing.md * 2
                visible: root.pendingDelete !== null
                radius: Theme.card.radius
                color: Qt.rgba(Theme.colors.error.r, Theme.colors.error.g, Theme.colors.error.b, 0.14)
                ColumnLayout {
                    id: confirmation
                    anchors.fill: parent
                    anchors.margins: Theme.spacing.lg
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
                        Layout.alignment: Qt.AlignRight
                        ZendaButton {
                            label: "Cancelar"
                            onClicked: root.pendingDelete = null
                        }
                        ZendaButton {
                            label: "Borrar tema"
                            destructive: true
                            enabled: !ZendaTheme.busy
                            onClicked: {
                                if (root.pendingDelete?.builtin === false)
                                    ZendaTheme.remove(root.pendingDelete.name);
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
                cellWidth: width / root.columns
                cellHeight: root.cellHeight
                model: ZendaTheme.themes
                // The list steps back while a deletion waits for confirmation.
                enabled: root.pendingDelete === null
                opacity: enabled ? 1 : 0.35
                ScrollBar.vertical: ScrollBar {}
                delegate: ThemeCard {
                    required property var modelData
                    themeInfo: modelData
                    width: grid.cellWidth - Theme.spacing.md
                    height: grid.cellHeight - Theme.spacing.md
                    onEditRequested: info => root.editTheme(info, true)
                    onDuplicateRequested: info => root.editTheme(info, false, true)
                    onDeleteRequested: info => root.pendingDelete = info
                }
            }
        }
    }

}
