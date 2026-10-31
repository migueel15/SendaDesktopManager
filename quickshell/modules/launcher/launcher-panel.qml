import QtQuick
import Quickshell
import qs.common
import qs.common.components
import qs.services
import "search.js" as Search
import "emojis.js" as Emojis

// Launcher for applications, Senda actions, arithmetic, shell commands (">"),
// emoji (":") and the clipboard history ("#"). It unfolds from the bar like the other overlay panels;
// history, launching and IPC live in LauncherService.
SendaPanel {
    id: root
    property bool viewReady: false

    name: "launcher"
    padding: 16
    targetWidth: Math.min(Theme.scaled(640), parent.width - 24)
    // Below the bar, leaving room for the shadow.
    targetHeight: Math.min(Theme.scaled(520), Math.max(0, parent.height - Theme.barSize - 20)) - 2 * padding
    targetX: parent.width / 2 - width / 2

    // Each result has a kind, a name, an optional detail, an icon name or a
    // glyph, and run(), which performs it from the launcher.
    property var results: []

    // An action fills the search box or closes the launcher and opens its interface.
    function runAction(entry) {
        if (entry.query) {
            search.text = entry.query;
            return;
        }
        LauncherService.close();
        entry.open(root.screenName);
    }
    function actionResult(entry) {
        return { kind: "action", name: entry.name, detail: entry.detail, glyph: entry.glyph, run: () => root.runAction(entry) };
    }
    function copy(text) {
        LauncherService.close();
        Quickshell.execDetached(["wl-copy", "--", text]);
    }
    function appResult(entry) {
        return { kind: "app", name: entry.name, icon: entry.icon || "application-x-executable", run: () => LauncherService.launch(entry) };
    }

    // ":" searches emoji, ">" runs a shell command, arithmetic shows its result
    // and any other text searches applications and Senda actions together.
    function refresh() {
        const text = search.text.trim();
        let results;
        if (text.startsWith(":")) {
            results = Emojis.search(text.slice(1)).map(([emoji, keywords]) =>
                ({ kind: "emoji", name: keywords.split(" ").slice(0, 3).join(" "), detail: "Copiar al portapapeles", glyph: emoji, run: () => root.copy(emoji) }));
        } else if (text.startsWith("#")) {
            const query = text.slice(1).trim().toLocaleLowerCase();
            results = SendaClipboard.entries.filter(entry => entry.text.toLocaleLowerCase().includes(query)).map(entry =>
                ({ kind: "clipboard", name: entry.text.trim().replace(/\s+/g, " ").slice(0, 200), detail: "Restaurar al portapapeles", glyph: "󰅌", run: () => {
                            LauncherService.close();
                            SendaClipboard.restore(entry.id);
                } }));
        } else if (text.startsWith(">")) {
            const command = text.slice(1).trim();
            results = command ? [{ kind: "command", name: command, detail: "Ejecutar comando", glyph: "󰆍", run: () => {
                        LauncherService.close();
                        Quickshell.execDetached(["sh", "-c", command]);
            } }] : [];
        } else {
            const query = text.toLocaleLowerCase();
            const value = Search.calculate(text);
            results = value === null ? [] : [{ kind: "calc", name: value, detail: text.replace(/^=/, "") + " · Copiar resultado", glyph: "󰃬", run: () => root.copy(value) }];
            const apps = DesktopEntries.applications.values;
            const entries = query ? Array.from(apps).concat(LauncherActions.entries) : apps;
            results = results.concat(Search.sortEntries(entries, query, LauncherService.recentIds)
                .map(entry => entry.kind === "action" ? root.actionResult(entry) : root.appResult(entry)));
        }
        root.results = results;
        list.currentIndex = results.length ? 0 : -1;
    }
    function launch(index) {
        if (index >= 0 && index < root.results.length) root.results[index].run();
    }

    // Each opening starts with an empty search and the keyboard in it.
    function prepareOpen() {
        if (!root.viewReady) return;
        if (!root.open) return;
        search.text = "";
        SendaClipboard.refresh();
        root.refresh();
        Qt.callLater(() => { if (root.open) search.forceActiveFocus(); });
    }
    onOpenChanged: prepareOpen()
    Component.onCompleted: {
        root.viewReady = true;
        prepareOpen();
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.refresh(); }
    }
    Connections {
        target: SendaClipboard
        function onEntriesChanged() { if (search.text.trim().startsWith("#")) root.refresh(); }
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
            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !search.text; text: "Buscar aplicaciones y acciones · = calcular · > comando · : emoji · # portapapeles"; color: Theme.colors.overlay; font: search.font }
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
            Item {
                id: appIcon
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 26; height: 26
                Image {
                    anchors.fill: parent
                    visible: !!row.modelData.icon
                    asynchronous: true
                    source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.centerIn: parent
                    visible: !row.modelData.icon
                    text: row.modelData.glyph || ""
                    color: Theme.colors.primary
                    font.pixelSize: row.modelData.kind === "emoji" ? Theme.scaled(22) : Theme.scaled(20)
                }
            }
            Column {
                anchors { left: appIcon.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    text: row.modelData.name
                    color: Theme.colors.text
                    font.pixelSize: Theme.scaled(15)
                    font.bold: row.modelData.kind === "calc"
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: !!row.modelData.detail
                    text: row.modelData.detail || ""
                    color: Theme.colors.overlay
                    font.pixelSize: Theme.scaled(12)
                    elide: Text.ElideRight
                }
            }
            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launch(row.index) }
        }
        Text { anchors.centerIn: parent; visible: list.count === 0; text: "Sin resultados"; color: Theme.colors.overlay; font.pixelSize: Theme.scaled(14) }
            }
        }
