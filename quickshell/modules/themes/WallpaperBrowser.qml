pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel
import qs.common
import qs.common.components.controls

// Image browser drawn inside the picker popup. A FileDialog is not native in a
// Quickshell layer: it renders inside this window and fights for its focus.
Rectangle {
    id: root

    property string startPath: ""
    signal picked(string path)
    signal cancelled()

    readonly property string picturesDir: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        .toString().replace(/^file:\/\//, "")

    function pathOf(url) {
        return decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
    }
    function dirOf(path) {
        const index = path.lastIndexOf("/");
        return index > 0 ? path.substring(0, index) : "/";
    }
    function open() {
        const dir = startPath.startsWith("/") ? dirOf(startPath) : picturesDir;
        folderModel.folder = "file://" + (dir || "/");
    }

    color: Theme.card.fill
    radius: Theme.card.radius
    implicitHeight: 260
    Component.onCompleted: open()

    FolderListModel {
        id: folderModel
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.PNG", "*.JPG", "*.JPEG", "*.GIF"]
        caseSensitive: false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.md
        spacing: Theme.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.sm
            ZendaIconButton {
                size: Theme.scaled(28)
                icon: "\uf062"
                accessibleLabel: "Carpeta superior"
                onClicked: folderModel.folder = folderModel.parentFolder
            }
            Text {
                Layout.fillWidth: true
                text: root.pathOf(folderModel.folder)
                elide: Text.ElideLeft
                font: Theme.font.caption
                color: Theme.colors.textMuted
            }

        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: folderModel
            spacing: 2
            delegate: ZendaListItem {
                required property string fileName
                required property url fileUrl
                required property bool fileIsDir
                width: ListView.view.width
                leadingIcon: fileIsDir ? "\uf07b" : "\uf03e"
                text: fileName
                trailingIcon: fileIsDir ? "\uf054" : ""
                onClicked: {
                    if (fileIsDir) folderModel.folder = fileUrl;
                    else root.picked(root.pathOf(fileUrl));
                }
            }
            Text {
                anchors.centerIn: parent
                visible: folderModel.status === FolderListModel.Ready && folderModel.count === 0
                text: "Sin imágenes en esta carpeta"
                font: Theme.font.caption
                color: Theme.colors.textMuted
            }
        }
    }
}
