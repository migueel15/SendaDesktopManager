pragma Singleton
import Quickshell

Singleton {
    id: root

    signal currentPanelUpdated

    property var currentPanel: ""

    function setCurrentPanel(panel: string) {
        root.currentPanel = panel;
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
