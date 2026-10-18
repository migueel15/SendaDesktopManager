pragma Singleton
import Quickshell

Singleton {
    id: root

    signal currentPanelUpdated

    property var currentPanel: ""
    // Monitor the open panel is shown on. It stays after the panel closes, so
    // later panels opened without a monitor appear where the user last was.
    property string currentScreen: ""

    // screenName is the monitor the panel opens on. Without it, the last monitor
    // is kept, or the first monitor when none was used yet.
    // screenName is left untyped on purpose: a typed string parameter turns a
    // missing argument into the text "undefined", which matches no monitor.
    function setCurrentPanel(panel: string, screenName) {
        root.currentPanel = panel;
        if (screenName) {
            root.currentScreen = screenName;
        } else if (root.currentScreen === "") {
            const first = Quickshell.screens.find(screen => true);
            root.currentScreen = first ? first.name : "";
        }
        console.log(panel);
        currentPanelUpdated();
    }

    function closeCurrentPanel() {
        root.currentPanel = "";
        currentPanelUpdated();
    }

    function isOpen(panel: string): bool {
        return root.currentPanel === panel;
    }
}
