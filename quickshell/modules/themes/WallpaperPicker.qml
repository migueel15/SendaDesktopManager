pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.services
import qs.common.components.barextension as BarComponents

PanelWindow {
    id: root
    property bool viewReady: false

    required property var modelData
    readonly property bool onPickerScreen: WallpaperService.pickerScreen === modelData.name
        || (WallpaperService.pickerScreen === "" && modelData === Quickshell.screens[0])
    readonly property bool open: onPickerScreen && WallpaperService.pickerOpen
    readonly property bool builtinTheme: SendaTheme.active?.builtin !== false
    readonly property string selectedPath: list.currentItem?.filePath ?? ""
    readonly property real panelHeight: Math.min(Theme.scaled(340), height - extension.shadowSpace)
    readonly property bool retainWhenHidden: naming || importProcess.running || pendingCopy !== ""
    property bool browsing: false
    property bool naming: false
    property string message: ""
    // Theme copy to apply once saved, and the image to select once imported.
    property string pendingCopy: ""
    property string pendingSelection: ""

    function close() { WallpaperService.closePicker(); }
    function selectPending() {
        for (let i = 0; pendingSelection !== "" && i < folderModel.count; i++) {
            if (folderModel.get(i, "filePath") === pendingSelection) {
                list.currentIndex = i;
                pendingSelection = "";
            }
        }
    }
    function applySession() {
        message = WallpaperService.setForSession(selectedPath);
        if (message === "")
            close();
    }
    function saveToTheme() {
        if (builtinTheme) {
            naming = true;
            nameField.text = SendaTheme.active.name + "-copia";
            nameField.forceActiveFocus();
        } else {
            const name = SendaTheme.active.name;
            pendingCopy = "";
            SendaTheme.save({name: name, original: name, colors: SendaTheme.active.colors, wallpaper: selectedPath});
        }
    }
    function saveCopy() {
        pendingCopy = nameField.text;
        SendaTheme.save({name: pendingCopy, colors: SendaTheme.active.colors, wallpaper: selectedPath});
    }

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.namespace: "Senda:WallpaperPicker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || extension.height > 0.01
    mask: Region { item: root.open ? backdrop : panel }

    function prepareOpen() {
        if (!root.viewReady) return;
        if (!open)
            return;
        browsing = false;
        message = "";
        folderProcess.running = true;
        SendaTheme.refresh();
        Qt.callLater(() => content.forceActiveFocus());
    }

    onOpenChanged: prepareOpen()
    Component.onCompleted: {
        root.viewReady = true;
        prepareOpen();
    }

    // The folder must exist before the model can watch it.
    Process {
        id: folderProcess
        command: ["mkdir", "-p", WallpaperService.wallpapersDirectory]
        onExited: folderModel.folder = "file://" + WallpaperService.wallpapersDirectory
    }

    Process {
        id: importProcess
        stdout: StdioCollector { id: importOutput }
        stderr: StdioCollector { id: importErrors }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.pendingSelection = importOutput.text.trim();
                root.selectPending();
            } else {
                root.message = importErrors.text.trim() || "No se pudo importar la imagen";
            }
        }
    }

    Connections {
        target: SendaTheme
        function onSaved(info) {
            if (!root.open)
                return;
            if (root.pendingCopy === info.name) {
                root.pendingCopy = "";
                // The save process is still finishing.
                Qt.callLater(() => SendaTheme.apply(info.name));
            }
            root.close();
        }
        function onSaveFailed(error) {
            if (root.open)
                root.message = error;
        }
    }

    FolderListModel {
        id: folderModel
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif"]
        caseSensitive: false
        onCountChanged: root.selectPending()
    }

    MouseArea {
        id: backdrop
        anchors.fill: parent
        enabled: root.open
        onPressed: root.close()
    }

    Item {
        id: panel
        width: Math.min(Theme.scaled(960), root.width)
        height: extension.height
        x: Math.round((root.width - width) / 2)
        anchors.bottom: parent.bottom

        // Swallows clicks on empty parts of the panel.
        MouseArea { anchors.fill: parent; enabled: root.open }

        // The extension hangs from the top bar; mirrored, it rises from the bottom.
        BarComponents.BarExtension {
            id: extension
            width: parent.width
            expanded: root.open
            expandedHeight: root.panelHeight
            autoHideOnPointerExit: false
            conflictGroup: "tray-popups"
            onCloseRequested: root.close()
            transform: Scale { origin.y: extension.height / 2; yScale: -1 }
        }

        FocusScope {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: extension.curveWidth + Theme.spacing.md
            anchors.rightMargin: extension.curveWidth + Theme.spacing.md
            anchors.topMargin: Theme.spacing.md
            height: root.panelHeight - Theme.spacing.md * 2
            opacity: extension.height / root.panelHeight

            Keys.onEscapePressed: event => {
                if (root.browsing || root.naming) {
                    root.browsing = root.naming = false;
                    content.forceActiveFocus();
                } else {
                    root.close();
                }
                event.accepted = true;
            }
            Keys.onLeftPressed: list.decrementCurrentIndex()
            Keys.onRightPressed: list.incrementCurrentIndex()
            Keys.onReturnPressed: {
                if (!root.browsing && !root.naming && root.selectedPath !== "")
                    root.applySession();
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacing.sm

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: root.browsing
                    visible: active
                    sourceComponent: Component {
                        WallpaperBrowser {
                            onCancelled: root.browsing = false
                            onPicked: path => {
                                root.browsing = false;
                                root.message = "";
                                importProcess.command = [SendaManager.binaryPath, "wallpaper", "import", path];
                                importProcess.running = true;
                            }
                        }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.browsing
                    orientation: ListView.Horizontal
                    spacing: Theme.spacing.md
                    clip: true
                    model: folderModel
                    currentIndex: 0
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: (width - Theme.scaled(300)) / 2
                    preferredHighlightEnd: (width + Theme.scaled(300)) / 2
                    highlightMoveDuration: Theme.motion.slow
                    delegate: Rectangle {
                        id: card
                        required property int index
                        required property string filePath
                        required property url fileUrl
                        readonly property bool current: ListView.isCurrentItem
                        width: Theme.scaled(300)
                        height: ListView.view.height
                        radius: Theme.rounding.normal
                        color: Theme.colors.surface
                        border.width: 2
                        border.color: current ? Theme.colors.focus : Theme.colors.border
                        opacity: current ? 1 : 0.65
                        scale: current ? 1 : 0.9
                        Behavior on scale { NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: Theme.motion.slow } }
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: card.fileUrl
                            cache: false
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: Theme.scaled(600)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                list.currentIndex = card.index;
                                content.forceActiveFocus();
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: "No hay fondos: importa una imagen o déjala en la carpeta wallpapers"
                        font: Theme.font.body
                        color: Theme.colors.textMuted
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.message || SendaTheme.lastError
                    font: Theme.font.caption
                    color: Theme.colors.error
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.naming && !root.browsing
                    Text {
                        text: "El tema es de solo lectura. Nombre de la copia:"
                        font: Theme.font.body
                        color: Theme.colors.text
                    }
                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        font: Theme.font.body
                        color: Theme.colors.text
                        validator: RegularExpressionValidator { regularExpression: /[a-z0-9]+(-[a-z0-9]+)*/ }
                        onAccepted: if (copyButton.enabled) root.saveCopy()
                    }
                    ActionButton {
                        id: copyButton
                        text: "Crear copia"
                        enabled: nameField.acceptableInput && nameField.length <= 40 && !SendaTheme.busy
                        onClicked: root.saveCopy()
                    }
                    ActionButton {
                        text: "Cancelar"
                        onClicked: root.naming = false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.naming && !root.browsing
                    ActionButton {
                        text: importProcess.running ? "Importando…" : "Importar…"
                        enabled: !importProcess.running
                        onClicked: root.browsing = true
                    }
                    Item { Layout.fillWidth: true }
                    ActionButton {
                        text: "Solo esta sesión"
                        enabled: root.selectedPath !== ""
                        onClicked: root.applySession()
                    }
                    ActionButton {
                        text: "Guardar en el tema"
                        enabled: root.selectedPath !== "" && !!SendaTheme.active && !SendaTheme.busy
                        onClicked: root.saveToTheme()
                    }
                    ActionButton {
                        text: "Cerrar"
                        onClicked: root.close()
                    }
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
            opacity: button.enabled ? 1 : 0.5
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
