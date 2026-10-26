import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.common.components.barextension

PanelWindow {
    id: root
    property string screenName: ""
    property var results: []
    property var recentIds: []
    property var pendingIds: []
    property bool historyReady: false
    property bool historyWritable: true
    property bool expanded: false
    readonly property string historyDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/senda"
    screen: Quickshell.screens.find(s => s.name === root.screenName) || Quickshell.screens[0] || null
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barSize
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "Senda:Launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: root.expanded || panel.height > 0.01
    mask: Region { item: root.expanded ? backdrop : panel }

    function refresh() {
        const query = search.text.trim().toLocaleLowerCase();
        root.results = DesktopEntries.applications.values.filter(entry => {
            if (entry.noDisplay || !entry.name) return false;
            const terms = [entry.name, entry.genericName, entry.comment, entry.id].concat(entry.keywords || []);
            return terms.some(term => (term || "").toLocaleLowerCase().includes(query));
        }).sort((a, b) => {
            const aIndex = root.recentIds.indexOf(a.id);
            const bIndex = root.recentIds.indexOf(b.id);
            if (aIndex !== -1 || bIndex !== -1)
                return aIndex === -1 ? 1 : bIndex === -1 ? -1 : aIndex - bIndex;
            return a.name.localeCompare(b.name);
        });
        list.currentIndex = root.results.length ? 0 : -1;
    }
    function toggle(name) {
        if (root.expanded) { root.expanded = false; return; }
        root.screenName = name || Hyprland.focusedMonitor?.name || "";
        search.text = "";
        root.refresh();
        root.expanded = true;
        Qt.callLater(() => search.forceActiveFocus());
    }
    function launch(index) {
        if (index < 0 || index >= root.results.length) return;
        const entry = root.results[index];
        root.recordLaunch(entry.id);
        root.expanded = false;
        entry.execute();
    }
    function addRecent(id) {
        if (typeof id !== "string" || !id) return;
        root.recentIds = [id].concat(root.recentIds.filter(existing => existing !== id)).slice(0, 100);
    }
    function recordLaunch(id) {
        if (!root.historyReady) {
            root.pendingIds = root.pendingIds.concat([id]);
            root.addRecent(id);
            return;
        }
        root.addRecent(id);
        root.saveHistory();
    }
    function finishHistory(ids) {
        root.recentIds = ids;
        for (const id of root.pendingIds) root.addRecent(id);
        const changed = root.pendingIds.length > 0;
        root.pendingIds = [];
        root.historyReady = true;
        if (changed) root.saveHistory();
        root.refresh();
    }
    function saveHistory() {
        if (root.historyWritable)
            historyFile.setText(JSON.stringify({version: 1, recent: root.recentIds}, null, 2) + "\n");
    }
    Component.onCompleted: historyDirectoryProcess.running = true
    Process {
        id: historyDirectoryProcess
        command: ["mkdir", "-p", root.historyDirectory]
        onExited: exitCode => {
            if (exitCode === 0) historyFile.path = root.historyDirectory + "/launcher-recent.json";
            else { root.historyWritable = false; root.finishHistory([]); }
        }
    }
    FileView {
        id: historyFile
        path: ""
        atomicWrites: true
        blockWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(historyFile.text());
                if (!data || data.version !== 1 || !Array.isArray(data.recent)) throw new Error("invalid history");
                const ids = [];
                for (const id of data.recent)
                    if (typeof id === "string" && id && !ids.includes(id) && ids.length < 100) ids.push(id);
                root.finishHistory(ids);
            } catch (error) {
                console.warn("Launcher: invalid history:", error);
                root.historyWritable = false;
                root.finishHistory([]);
            }
        }
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) {
                console.warn("Launcher: history load failed:", FileViewError.toString(error));
                root.historyWritable = false;
            }
            root.finishHistory([]);
        }
        onSaveFailed: error => console.warn("Launcher: history save failed:", FileViewError.toString(error))
    }
    IpcHandler {
        target: "launcher"
        function toggle() { root.toggle(""); }
        function toggleOnScreen(screenName: string) { root.toggle(screenName); }
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.refresh(); }
    }
    MouseArea { id: backdrop; anchors.fill: parent; enabled: root.expanded; onClicked: root.expanded = false }
    BarExtension {
        id: panel
        width: Math.min(Theme.scaled(640), parent.width - 24)
        expanded: root.expanded
        expandedHeight: Math.min(Theme.scaled(520), Math.max(0, parent.height - shadowSpace))
        autoHideOnPointerExit: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: -collapseLift
        MouseArea { anchors.fill: parent }
        Item {
            id: searchBox
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
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
                Keys.onEscapePressed: root.expanded = false
                Keys.onDownPressed: { if (list.count) list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1); }
                Keys.onUpPressed: { if (list.count) list.currentIndex = Math.max(list.currentIndex - 1, 0); }
                Keys.onReturnPressed: root.launch(list.currentIndex)
                Keys.onEnterPressed: root.launch(list.currentIndex)
                Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !search.text; text: "Buscar aplicaciones…"; color: Theme.colors.overlay; font: search.font }
            }
        }
        ListView {
            id: list
            anchors { top: searchBox.bottom; left: parent.left; right: parent.right; margins: 16; topMargin: 8 }
            height: Math.max(0, panel.expandedHeight - searchBox.height - 40)
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
}
