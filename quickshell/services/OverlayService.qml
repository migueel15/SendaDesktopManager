pragma Singleton
import Quickshell

Singleton {
    id: root

    signal currentPanelUpdated

    property var currentPanel: ""
    // Monitor the open panel is shown on. It stays after the panel closes, so
    // later panels opened without a monitor appear where the user last was.
    property string currentScreen: ""
    // Panel to go back to when the current one closes, e.g. the dashboard after
    // the settings opened from it. Empty closes everything.
    property string returnPanel: ""

    // screenName is the monitor the panel opens on. Without it, the last monitor
    // is kept, or the first monitor when none was used yet.
    // screenName is left untyped on purpose: a typed string parameter turns a
    // missing argument into the text "undefined", which matches no monitor.
    function setCurrentPanel(panel: string, screenName) {
        root.returnPanel = panel === "settings" && root.currentPanel === "dashboard" ? "dashboard" : "";
        // Set the monitor first: the overlay layers map when currentPanel
        // changes, and they must already know which one takes the keyboard.
        if (screenName) {
            root.currentScreen = screenName;
        } else if (root.currentScreen === "") {
            const first = Quickshell.screens.find(screen => true);
            root.currentScreen = first ? first.name : "";
        }
        root.currentPanel = panel;
        console.log(panel);
        currentPanelUpdated();
    }

    // Bar buttons use this so a second click on the same button closes its panel.
    function togglePanel(panel: string, screenName) {
        if (root.currentPanel === panel && (!screenName || root.currentScreen === screenName))
            closeCurrentPanel();
        else
            setCurrentPanel(panel, screenName);
    }

    function closeCurrentPanel() {
        root.returnPanel = "";
        root.currentPanel = "";
        currentPanelUpdated();
    }

    // Closes the current panel, going back to the panel it was opened from if any.
    // Clicks outside the panels still close everything.
    function closeOrGoBack() {
        if (root.returnPanel !== "")
            setCurrentPanel(root.returnPanel);
        else
            closeCurrentPanel();
    }

    function isOpen(panel: string): bool {
        return root.currentPanel === panel;
    }
}
