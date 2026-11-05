pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel
import Quickshell.Widgets
import qs.common
import qs.common.components.icons
import qs.common.components.controls
import qs.services

// Image browser drawn inside the picker popup. A FileDialog is not native in a
// Quickshell layer: it renders inside this window and fights for its focus.
// Folders and images are shown as a thumbnail grid, with quick places on top.
Rectangle {
    id: root

    property string startPath: ""
    signal picked(string path)
    signal cancelled()

    function location(kind) {
        return StandardPaths.writableLocation(kind).toString().replace(/^file:\/\//, "");
    }
    readonly property string picturesDir: root.location(StandardPaths.PicturesLocation)
    readonly property string currentPath: root.pathOf(folderModel.folder)
    readonly property var places: [
        { label: "Imágenes", icon: "", path: root.picturesDir },
        { label: "Descargas", icon: "", path: root.location(StandardPaths.DownloadLocation) },
        { label: "Inicio", icon: "", path: root.location(StandardPaths.HomeLocation) },
        { label: "Fondos de Zenda", icon: "", path: WallpaperService.wallpapersDirectory }
    ]
    // Each segment of the current path, so any parent can be opened with one click.
    readonly property var crumbs: {
        const parts = root.currentPath.split("/").filter(part => part !== "");
        const result = [{ label: "/", path: "/" }];
        let path = "";
        for (const part of parts) {
            path += "/" + part;
            result.push({ label: part, path: path });
        }
        return result;
    }

    function pathOf(url) {
        return decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
    }
    function dirOf(path) {
        const index = path.lastIndexOf("/");
        return index > 0 ? path.substring(0, index) : "/";
    }
    function go(path) {
        folderModel.folder = "file://" + (path || "/");
    }
    function open() {
        root.go(startPath.startsWith("/") ? root.dirOf(startPath) : root.picturesDir);
    }

    color: Theme.card.fill
    radius: Theme.card.radius
    implicitHeight: Theme.scaled(380)
    Component.onCompleted: { open(); grid.forceActiveFocus(); }

    FolderListModel {
        id: folderModel
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.PNG", "*.JPG", "*.JPEG", "*.GIF"]
        caseSensitive: false
    }

    // Rounded pill used for quick places and path segments.
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property bool current: false
        signal clicked()
        implicitWidth: pillRow.implicitWidth + 2 * Theme.spacing.sm
        implicitHeight: pillRow.implicitHeight + 2 * Theme.spacing.xs
        radius: Theme.rounding.full
        color: pill.current ? Theme.colors.selection : "transparent"
        ZendaStateLayer { hovered: pillHover.hovered }
        border.width: pill.current ? 0 : 1
        border.color: Theme.colors.border
        Accessible.role: Accessible.Button
        Accessible.name: pill.label
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spacing.xs
            ZendaIcon {
                visible: pill.icon !== ""
                text: pill.icon
                color: pill.current ? Theme.colors.primary : Theme.colors.overlay
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: pill.label
                font: Theme.font.caption
                color: pill.current ? Theme.colors.text : Theme.colors.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: pill.clicked() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.md
        spacing: Theme.spacing.sm

        // Quick places.
        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing.xs
            Repeater {
                model: root.places
                delegate: Pill {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.label
                    current: root.currentPath === modelData.path
                    onClicked: root.go(modelData.path)
                }
            }
        }

        // Path: up button and clickable segments.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.xs
            ZendaIconButton {
                size: Theme.scaled(26)
                icon: ""
                accessibleLabel: "Carpeta superior"
                enabled: root.currentPath !== "/"
                onClicked: folderModel.folder = folderModel.parentFolder
            }
            ListView {
                id: crumbList
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.scaled(24)
                orientation: ListView.Horizontal
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.crumbs
                onCountChanged: positionViewAtEnd()
                delegate: Row {
                    id: crumb
                    required property var modelData
                    required property int index
                    spacing: 2
                    height: crumbList.height
                    Text {
                        visible: crumb.index > 1
                        text: "›"
                        font: Theme.font.caption
                        color: Theme.colors.overlay
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        border.width: 0
                        label: crumb.modelData.label
                        current: crumb.index === crumbList.count - 1
                        onClicked: root.go(crumb.modelData.path)
                    }
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            focus: true
            model: folderModel
            readonly property int columns: Math.max(2, Math.floor(width / Theme.scaled(130)))
            cellWidth: Math.floor((width - gridBar.width) / columns)
            cellHeight: cellWidth * 0.62 + Theme.scaled(26)
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            Keys.onEscapePressed: root.cancelled()
            Keys.onReturnPressed: currentItem?.activate()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Backspace) {
                    folderModel.folder = folderModel.parentFolder;
                    event.accepted = true;
                }
            }
            ScrollBar.vertical: ScrollBar {
                id: gridBar
                width: Theme.spacing.xs + 2
                policy: grid.contentHeight > grid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                contentItem: Rectangle {
                    implicitWidth: gridBar.width
                    radius: Theme.rounding.full
                    color: Theme.colors.overlay
                }
            }

            delegate: Item {
                id: tile
                required property string fileName
                required property url fileUrl
                required property bool fileIsDir
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                function activate() {
                    if (tile.fileIsDir) folderModel.folder = tile.fileUrl;
                    else root.picked(root.pathOf(tile.fileUrl));
                }
                Accessible.role: Accessible.Button
                Accessible.name: tile.fileIsDir ? `Carpeta ${tile.fileName}` : tile.fileName

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing.xs / 2
                    radius: Theme.rounding.normal
                    color: tileHover.hovered || grid.currentIndex === tile.index && grid.activeFocus
                        ? Theme.colors.surfaceVariant : "transparent"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing.xs
                        spacing: Theme.spacing.xs

                        ClippingRectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.rounding.normal
                            color: Theme.colors.surfaceVariant
                            Text {
                                visible: tile.fileIsDir || thumb.status !== Image.Ready
                                anchors.centerIn: parent
                                text: tile.fileIsDir ? "" : ""
                                font.family: Theme.font.icon.family
                                font.pixelSize: Theme.scaled(26)
                                color: tile.fileIsDir ? Theme.colors.primary : Theme.colors.overlay
                            }
                            Image {
                                id: thumb
                                anchors.fill: parent
                                visible: !tile.fileIsDir
                                source: tile.fileIsDir ? "" : tile.fileUrl
                                sourceSize: Qt.size(256, 160)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: tile.fileName
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                            font: Theme.font.caption
                            color: Theme.colors.textMuted
                        }
                    }
                }
                HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { grid.currentIndex = tile.index; tile.activate(); } }
            }

            Text {
                anchors.centerIn: parent
                visible: folderModel.status === FolderListModel.Ready && folderModel.count === 0
                text: "Sin imágenes ni carpetas aquí"
                font: Theme.font.caption
                color: Theme.colors.textMuted
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Pulsa una imagen para elegirla · Esc para cerrar"
                font: Theme.font.caption
                color: Theme.colors.overlay
                elide: Text.ElideRight
            }
            ZendaButton { label: "Cancelar"; onClicked: root.cancelled() }
        }
    }
}
