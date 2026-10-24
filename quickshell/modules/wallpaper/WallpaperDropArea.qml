import QtQuick

import qs.services

DropArea {
    id: dropArea

    required property var screen

    anchors.fill: parent

    onDropped: drop => {
        const path = drop.hasUrls && drop.urls.length > 0 ? String(drop.urls[0]) : drop.text;
        const x = Math.round(drop.x);
        const y = Math.round(dropArea.height - drop.y);
        SendaManager.setWallpaper(screen, path, x, y);
        drop.accept();
    }
}
