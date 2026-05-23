import Quickshell
import QtQuick

import qs.common.services

DropArea {
    id: dropArea

    required property var screen

    anchors.fill: parent

    onDropped: drop => {
        const path = drop.text;
        const x = Math.round(drop.x);
        const y = Math.round(dropArea.height - drop.y);
        SendaManager.setWallpaper(screen, path, x, y);
        drop.accept();
    }
}
