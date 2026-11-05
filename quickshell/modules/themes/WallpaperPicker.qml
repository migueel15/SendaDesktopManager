pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.common.components.controls
import qs.services
import qs.common.components.barextension as BarComponents

PanelWindow {
    id: root
    property bool viewReady: false

    required property var modelData
    readonly property bool onPickerScreen: WallpaperService.pickerScreen === modelData.name
        || (WallpaperService.pickerScreen === "" && modelData === Quickshell.screens[0])
    // Debug keeps the picker open on the debug screen, without the backdrop
    // or exclusive keyboard focus, so it can stay on screen while it changes.
    readonly property bool debugOpen: Debug.enabled && Debug.panel === "wallpapers" && modelData.name === Debug.debugScreenName
    readonly property bool open: onPickerScreen && WallpaperService.pickerOpen || debugOpen
    readonly property bool builtinTheme: ZendaTheme.active?.builtin !== false
    readonly property string selectedPath: list.currentItem?.filePath ?? ""
    readonly property real panelHeight: Math.min(Theme.scaled(400), height - extension.shadowSpace)
    readonly property bool retainWhenHidden: naming || importProcess.running || pendingCopy !== ""
    property bool browsing: false
    property bool naming: false
    property string message: ""
    // Theme copy to apply once saved, and the image to select once imported.
    property string pendingCopy: ""
    property string pendingSelection: ""
    // Wallpaper waiting for a second click on its delete button.
    property string confirmDelete: ""

    // Themes whose wallpaper is this file; deleting it would make them invalid.
    function themesUsing(path) {
        return ZendaTheme.themes.filter(theme => theme.wallpaper === path).map(theme => theme.name);
    }
    function requestDelete(path) {
        const users = root.themesUsing(path);
        if (users.length > 0) {
            root.message = `No se puede borrar: lo usa el tema ${users.join(", ")}`;
            return;
        }
        if (root.confirmDelete !== path) {
            root.confirmDelete = path;
            return;
        }
        root.confirmDelete = "";
        root.message = "";
        // Only files listed from the wallpapers folder reach this point.
        deleteProcess.command = ["rm", "--", path];
        deleteProcess.running = true;
    }

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
            nameField.text = ZendaTheme.active.name + "-copia";
            nameField.focusInput();
        } else {
            const name = ZendaTheme.active.name;
            pendingCopy = "";
            ZendaTheme.save({name: name, original: name, colors: ZendaTheme.active.colors, wallpaper: selectedPath});
        }
    }
    function saveCopy() {
        pendingCopy = nameField.text;
        ZendaTheme.save({name: pendingCopy, colors: ZendaTheme.active.colors, wallpaper: selectedPath});
    }

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.namespace: "Zenda:WallpaperPicker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && !debugOpen ? WlrKeyboardFocus.Exclusive : debugOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || extension.height > 0.01
    mask: Region { item: root.open && !root.debugOpen ? backdrop : panel }

    function prepareOpen() {
        if (!root.viewReady) return;
        if (!open)
            return;
        browsing = false;
        message = "";
        confirmDelete = "";
        folderProcess.running = true;
        ZendaTheme.refresh();
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
        id: deleteProcess
        stderr: StdioCollector { id: deleteErrors }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.message = deleteErrors.text.trim() || "No se pudo borrar el fondo";
        }
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
        target: ZendaTheme
        function onSaved(info) {
            if (!root.open)
                return;
            if (root.pendingCopy === info.name) {
                root.pendingCopy = "";
                // The save process is still finishing.
                Qt.callLater(() => ZendaTheme.apply(info.name));
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
        enabled: root.open && !root.debugOpen
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

        // A BarExtension that grows out of the bottom frame.
        BarComponents.BarExtension {
            id: extension
            edge: "bottom"
            width: parent.width
            expanded: root.open
            expandedHeight: root.panelHeight
            autoHideOnPointerExit: false
            conflictGroup: "tray-popups"
            onCloseRequested: root.close()
        }

        FocusScope {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: extension.curveWidth + Theme.spacing.md
            anchors.rightMargin: extension.curveWidth + Theme.spacing.md
            anchors.topMargin: Theme.spacing.lg
            height: root.panelHeight - Theme.spacing.lg * 2
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
                spacing: Theme.spacing.md

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.sm
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: root.browsing ? "Importar fondo" : "Fondos"
                            font.family: Theme.textFamily
                            font.pixelSize: Theme.scaled(20)
                            font.weight: Font.DemiBold
                            color: Theme.colors.text
                        }
                        Text {
                            text: root.browsing ? "Elige una imagen" : folderModel.count === 1 ? "1 fondo" : `${folderModel.count} fondos`
                            font: Theme.font.caption
                            color: Theme.colors.overlay
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ZendaButton {
                        visible: !root.browsing
                        label: importProcess.running ? "Importando…" : "Importar"
                        busy: importProcess.running
                        enabled: !importProcess.running
                        onClicked: root.browsing = true
                    }
                    ZendaIconButton {
                        icon: "\uf00d"
                        accessibleLabel: "Cerrar"
                        onClicked: root.browsing ? root.browsing = false : root.close()
                    }
                }

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
                                importProcess.command = [ZendaManager.binaryPath, "wallpaper", "import", path];
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
                    // Room for the selection ring, which sits outside the card.
                    readonly property real ringRoom: Theme.spacing.md
                    leftMargin: ringRoom; rightMargin: ringRoom
                    clip: true
                    model: folderModel
                    currentIndex: 0
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: (width - Theme.scaled(300)) / 2
                    preferredHighlightEnd: (width + Theme.scaled(300)) / 2
                    highlightMoveDuration: Theme.motion.slow
                    delegate: Item {
                        id: card
                        required property int index
                        required property string filePath
                        required property url fileUrl
                        readonly property bool current: ListView.isCurrentItem
                        width: Theme.scaled(300)
                        height: ListView.view.height
                        opacity: current ? 1 : hover.hovered ? 0.85 : 0.6
                        scale: current ? 1 : 0.92
                        Behavior on scale { NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }

                        // Inset from the list's top and bottom, so the ring around it
                        // is never clipped. ListView places delegates at y = 0, so the
                        // inset lives inside the delegate.
                        ClippingRectangle {
                            id: frame
                            anchors.fill: parent
                            anchors.topMargin: list.ringRoom
                            anchors.bottomMargin: list.ringRoom
                            radius: Theme.card.radius
                            color: Theme.card.fill
                            Image {
                                anchors.fill: parent
                                source: card.fileUrl
                                cache: false
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: Theme.scaled(600)
                            }
                        }
                        // Selection ring and check badge on the current wallpaper.
                        Rectangle {
                            anchors.fill: frame
                            anchors.margins: -4
                            radius: Theme.card.radius + 4
                            color: "transparent"
                            border.width: 3
                            border.color: Theme.colors.primary
                            opacity: card.current ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
                        }
                        Rectangle {
                            anchors { top: frame.top; right: frame.right; margins: Theme.spacing.md }
                            width: Theme.scaled(26); height: width; radius: width / 2
                            color: Theme.colors.primary
                            scale: card.current ? 1 : 0
                            Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack } }
                            Text {
                                anchors.centerIn: parent
                                text: "\uf00c"
                                color: Theme.colors.base
                                font.family: Theme.iconFamily
                                font.pixelSize: Theme.scaled(12)
                            }
                        }
                        // Delete badge, just left of the check badge; a second click confirms.
                        Rectangle {
                            id: deleteBadge
                            readonly property bool confirming: root.confirmDelete === card.filePath
                            // Grows to the left when it asks for confirmation.
                            anchors { top: frame.top; right: frame.right; topMargin: Theme.spacing.md
                                rightMargin: Theme.spacing.md + Theme.scaled(26) + Theme.spacing.sm }
                            z: 1
                            width: confirming ? deleteRow.implicitWidth + 2 * Theme.spacing.sm : Theme.scaled(26)
                            height: Theme.scaled(26); radius: height / 2
                            color: confirming || deleteHover.hovered ? Theme.colors.error : Qt.alpha(Theme.colors.base, 0.75)
                            scale: card.current ? 1 : 0
                            enabled: card.current && !deleteProcess.running
                            Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack } }
                            Behavior on width { NumberAnimation { duration: Theme.motion.fast } }
                            Behavior on color { ColorAnimation { duration: Theme.motion.fast } }
                            Accessible.role: Accessible.Button
                            Accessible.name: confirming ? "Confirmar borrado del fondo" : "Borrar fondo"
                            Row {
                                id: deleteRow
                                anchors.centerIn: parent
                                spacing: Theme.spacing.xs
                                Text {
                                    text: "\uf1f8"
                                    color: deleteBadge.confirming || deleteHover.hovered ? Theme.colors.base : Theme.colors.error
                                    font.family: Theme.iconFamily
                                    font.pixelSize: Theme.scaled(12)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    visible: deleteBadge.confirming
                                    text: "¿Borrar?"
                                    color: Theme.colors.base
                                    font: Theme.font.caption
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            HoverHandler { id: deleteHover; cursorShape: Qt.PointingHandCursor }
                            // Exclusive grab, so the card never sees this tap or a double tap.
                            TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.requestDelete(card.filePath) }
                        }
                        onCurrentChanged: if (!current && root.confirmDelete === filePath) root.confirmDelete = ""
                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                list.currentIndex = card.index;
                                content.forceActiveFocus();
                            }
                            onDoubleTapped: root.applySession()
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
                    text: root.message || ZendaTheme.lastError
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
                    ZendaField {
                        id: nameField
                        Layout.fillWidth: true
                        placeholder: "nombre-del-tema"
                        onAccepted: if (copyButton.enabled) root.saveCopy()
                    }
                    ZendaButton {
                        label: "Cancelar"
                        onClicked: root.naming = false
                    }
                    ZendaButton {
                        id: copyButton
                        label: "Crear copia"
                        primary: true
                        enabled: /^[a-z0-9]+(-[a-z0-9]+)*$/.test(nameField.text) && nameField.text.length <= 40 && !ZendaTheme.busy
                        onClicked: root.saveCopy()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.naming && !root.browsing
                    spacing: Theme.spacing.sm
                    Text {
                        Layout.fillWidth: true
                        text: root.selectedPath.split("/").pop()
                        font: Theme.font.caption
                        color: Theme.colors.overlay
                        elide: Text.ElideMiddle
                    }
                    ZendaButton {
                        label: "Solo esta sesión"
                        enabled: root.selectedPath !== ""
                        onClicked: root.applySession()
                    }
                    ZendaButton {
                        label: "Guardar en el tema"
                        primary: true
                        enabled: root.selectedPath !== "" && !!ZendaTheme.active && !ZendaTheme.busy
                        onClicked: root.saveToTheme()
                    }
                }
            }
        }
    }

}
