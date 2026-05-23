pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

MouseArea {
    id: root

    required property SystemTrayItem modelData

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: 18
    implicitHeight: 18
    property bool trayReady: false

    Component.onCompleted: {
        trayReady = (root.modelData?.icon ?? "") !== "";
    }

    onClicked: event => {
        if (event.button === Qt.LeftButton) {
            modelData.activate();
        } else if (modelData.hasMenu) {
            const pos = root.mapToItem(root.QsWindow.window.contentItem, 0, root.height);
            menu.anchor.rect.x = pos.x;
            menu.anchor.rect.y = pos.y + 5;
            menu.open();
        }
    }

    QsMenuAnchor {
        id: menu
        menu: root.modelData.menu
        anchor.window: root.QsWindow.window
    }

    Connections {
        target: root.modelData

        function onReady() {
            root.trayReady = true;
        }
    }

    IconImage {
        id: trayIcon
        width: parent.implicitWidth
        height: parent.implicitHeight
        asynchronous: true
        source: root.trayReady ? (root.modelData?.icon ?? "") : ""
        anchors.centerIn: parent
    }
}
