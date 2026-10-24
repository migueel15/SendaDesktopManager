pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel
import qs.common

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

    color: Theme.colors.background
    radius: Theme.rounding.small
    border.color: Theme.colors.surfaceVariant
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
        anchors.margins: Theme.spacing.sm
        spacing: Theme.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.sm
            Text {
                text: "↑"
                font: Theme.font.heading
                color: upArea.containsMouse ? Theme.colors.primary : Theme.colors.text
                MouseArea {
                    id: upArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: folderModel.folder = folderModel.parentFolder
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.pathOf(folderModel.folder)
                elide: Text.ElideLeft
                font: Theme.font.caption
                color: Theme.colors.textMuted
            }
            Text {
                text: "Cerrar"
                font: Theme.font.body
                color: closeArea.containsMouse ? Theme.colors.primary : Theme.colors.text
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelled()
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: folderModel
            delegate: Rectangle {
                required property string fileName
                required property url fileUrl
                required property bool fileIsDir
                width: ListView.view.width
                height: 28
                radius: Theme.rounding.small
                color: rowArea.containsMouse ? Theme.colors.surfaceVariant : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing.sm
                    text: (parent.fileIsDir ? "▸ " : "") + parent.fileName
                    font: Theme.font.body
                    color: Theme.colors.text
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.fileIsDir) folderModel.folder = parent.fileUrl;
                        else root.picked(root.pathOf(parent.fileUrl));
                    }
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
