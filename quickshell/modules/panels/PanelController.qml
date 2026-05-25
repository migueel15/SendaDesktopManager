import QtQuick
import Quickshell
import qs.common
import qs.modules.panels.ControlCenter
import Quickshell.Wayland

PanelWindow {
    id: panelController

    WlrLayershell.namespace: "Senda:PopupController"

    property var currentPopup: null
    property bool hasOpenPopup: currentPopup !== null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore

    visible: hasOpenPopup
    color: "transparent"

    // Stay above regular windows and other panels
    aboveWindows: true
    focusable: true

    function showPopup(popup, x, y) {
        // Close current popup if exists
        if (currentPopup && currentPopup !== popup) {
            closeCurrentPopup();
        }
        currentPopup = popup;
        popup.targetX = x;
        popup.targetY = y;
        popup.open();
    }

    function closeCurrentPopup() {
        if (currentPopup && currentPopup.close) {
            currentPopup.close();
        }
        currentPopup = null;
    }

    function toggleControlCenter(x, y) {
        if (controlCenterPopup.isOpen) {
            closeCurrentPopup();
        } else {
            showPopup(controlCenterPopup, x, y);
        }
    }

    // Click anywhere to close popup
    MouseArea {
        anchors.fill: parent
        onPressed: panelController.closeCurrentPopup()
    }

    // Container for popup content
    Item {
        id: popupContent
        anchors.fill: parent
        focus: hasOpenPopup

        Keys.onEscapePressed: closeCurrentPopup()

        ControlCenterPopup {
            id: controlCenterPopup

            onIsOpenChanged: {
                if (isOpen) {
                    panelController.currentPopup = controlCenterPopup;
                    popupContent.forceActiveFocus();
                } else if (panelController.currentPopup === controlCenterPopup) {
                    panelController.currentPopup = null;
                }
            }
        }
    }
}
