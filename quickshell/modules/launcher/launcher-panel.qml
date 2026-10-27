import QtQuick
import Quickshell
import qs.common
import qs.common.components
import qs.services
import "search.js" as Search

// Application launcher. It unfolds from the bar like the other overlay
// panels; history, launching and IPC live in LauncherService.
SendaPanel {
    id: root

    name: "launcher"
    padding: 16
    targetWidth: Math.min(Theme.scaled(640), parent.width - 24)
    // Below the bar, leaving room for the shadow.
    targetHeight: Math.min(Theme.scaled(520), Math.max(0, parent.height - Theme.barSize - 20)) - 2 * padding
    targetX: parent.width / 2 - width / 2

    property var results: []

    function refresh() {
        const query = search.text.trim().toLocaleLowerCase();
        root.results = Search.sortEntries(DesktopEntries.applications.values, query, LauncherService.recentIds);
        list.currentIndex = root.results.length ? 0 : -1;
    }
    function launch(index) {
        if (index >= 0 && index < root.results.length) LauncherService.launch(root.results[index]);
    }

    // Each opening starts with an empty search and the keyboard in it.
    onOpenChanged: {
        if (!root.open) return;
        search.text = "";
        root.refresh();
        Qt.callLater(() => { if (root.open) search.forceActiveFocus(); });
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.refresh(); }
    }
    Connections {
        target: LauncherService
        function onRecentIdsChanged() { if (!root.open) root.refresh(); }
    }

    Item {
        id: searchBox
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.scaled(48)
        TextInput {
            id: search
            anchors { fill: parent; margins: 12 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.colors.text
            selectionColor: Theme.colors.selection
            font.pixelSize: Theme.scaled(16)
            clip: true
            onTextChanged: root.refresh()
            Keys.onEscapePressed: LauncherService.close()
            Keys.onDownPressed: { if (list.count) list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1); }
            Keys.onUpPressed: { if (list.count) list.currentIndex = Math.max(list.currentIndex - 1, 0); }
            Keys.onReturnPressed: root.launch(list.currentIndex)
            Keys.onEnterPressed: root.launch(list.currentIndex)
            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !search.text; text: "Buscar aplicaciones…"; color: Theme.colors.overlay; font: search.font }
        }
    }
    ListView {
        id: list
        anchors { top: searchBox.bottom; left: parent.left; right: parent.right; topMargin: 8 }
        height: Math.max(0, (root.targetHeight ?? 0) - searchBox.height - 8)
        clip: true
        model: root.results
        spacing: 2
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: Theme.scaled(56)
            radius: Theme.rounding.normal
            color: list.currentIndex === index ? Theme.colors.selection : rowMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"
            Image {
                id: appIcon
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 26; height: 26
                asynchronous: true
                source: Quickshell.iconPath(row.modelData.icon || "application-x-executable", true)
                fillMode: Image.PreserveAspectFit
            }
            Text {
                anchors { left: appIcon.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: row.modelData.name
                color: Theme.colors.text
                font.pixelSize: Theme.scaled(15)
                elide: Text.ElideRight
            }
            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(row.index) }
        }
        Text { anchors.centerIn: parent; visible: list.count === 0; text: "No se encontraron aplicaciones"; color: Theme.colors.overlay; font.pixelSize: Theme.scaled(14) }
    }
}
