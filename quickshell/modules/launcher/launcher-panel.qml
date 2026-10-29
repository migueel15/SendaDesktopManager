import QtQuick
import Quickshell
import qs.common
import qs.common.components
import qs.services
import "search.js" as Search
import "emojis.js" as Emojis

// Launcher for applications, Senda actions, arithmetic, shell commands (">")
// and emoji (":"). It unfolds from the bar like the other overlay panels;
// history, launching and IPC live in LauncherService.
SendaPanel {
    id: root

    name: "launcher"
    padding: 16
    targetWidth: Math.min(Theme.scaled(640), parent.width - 24)
    // Below the bar, leaving room for the shadow.
    targetHeight: Math.min(Theme.scaled(520), Math.max(0, parent.height - Theme.barSize - 20)) - 2 * padding
    targetX: parent.width / 2 - width / 2

    // Each result has a kind, a name, an optional detail, an icon name or a
    // glyph, and run(), which performs it from the launcher.
    property var results: []

    // Senda actions searched together with the applications.
    readonly property var actions: {
        const settings = [
            ["Apariencia", "tema escala fuente appearance"], ["Barra", "bar"], ["Widgets", "spotify discord"],
            ["Calendario", "google calendar agenda"], ["Tiempo", "weather clima ubicacion"],
            ["Dictado", "stt voz voice"], ["Sistema", "system atajos"], ["Actualización", "update actualizar"]
        ].map(([label, keywords]) => root.action("Ajustes: " + label, "Abrir esta sección de ajustes", "󰒓",
            "settings ajustes configuracion " + keywords, () => root.closeThen(() => SendaSettings.openSection(label))));
        return [
            root.action("Ajustes", "Abrir los ajustes de Senda", "󰒓", "settings configuracion preferencias",
                () => root.closeThen(() => SendaSettings.openSection(""))),
            root.action("Selector de temas", "Cambiar el tema de Senda", "󰏘", "theme tema colores picker",
                () => root.closeThen(() => SendaTheme.openPicker(root.screenName))),
            root.action("Emojis", "Buscar y copiar un emoji", "󰞅", "emoji emoticono :", () => { search.text = ":"; }),
            root.action("Captura de pantalla", "Seleccionar una zona y capturarla", "󰹑", "screenshot captura",
                () => root.closeThen(() => captureTimer.start())),
            root.action("Bloquear pantalla", "Bloquear la sesión", "󰌾", "lock bloquear",
                () => root.closeThen(() => LockService.lock()))
        ].concat(settings);
    }

    function action(name, detail, glyph, keywords, run) {
        return { kind: "action", name: name, genericName: detail, detail: detail, glyph: glyph, keywords: keywords.split(" "), run: run };
    }
    function closeThen(callback) {
        LauncherService.close();
        callback();
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
            const entries = query ? Array.from(apps).concat(root.actions) : apps;
            results = results.concat(Search.sortEntries(entries, query, LauncherService.recentIds)
                .map(entry => entry.kind === "action" ? entry : root.appResult(entry)));
        }
        root.results = results;
        list.currentIndex = results.length ? 0 : -1;
    }
    function launch(index) {
        if (index >= 0 && index < root.results.length) root.results[index].run();
    }

    Timer {
        // Lets the launcher fold away before the screen is frozen.
        id: captureTimer
        interval: 250
        onTriggered: ScreenshotService.capture()
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
            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !search.text; text: "Buscar aplicaciones y acciones · = calcular · > comando · : emoji"; color: Theme.colors.overlay; font: search.font }
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
