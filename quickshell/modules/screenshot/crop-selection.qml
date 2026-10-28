pragma ComponentBehavior: Bound
import QtQuick
import qs.common

Item {
    id: root
    property bool editable: false
    property real cropLeft: 0
    property real cropTop: 0
    property real cropRight: editable ? width : 0
    property real cropBottom: editable ? height : 0
    property real startX: 0
    property real startY: 0
    readonly property real selectionX: Math.min(cropLeft, cropRight)
    readonly property real selectionY: Math.min(cropTop, cropBottom)
    readonly property real selectionWidth: Math.abs(cropRight - cropLeft)
    readonly property real selectionHeight: Math.abs(cropBottom - cropTop)
    signal selected()
    signal cancelled()

    function reset() { cropLeft = 0; cropTop = 0; cropRight = width; cropBottom = height; }
    function clampX(value) { return Math.max(0, Math.min(width, value)); }
    function clampY(value) { return Math.max(0, Math.min(height, value)); }

    Rectangle { width: root.width; height: root.selectionY; color: "#99000000" }
    Rectangle { y: root.selectionY + root.selectionHeight; width: root.width; height: root.height - y; color: "#99000000" }
    Rectangle { y: root.selectionY; width: root.selectionX; height: root.selectionHeight; color: "#99000000" }
    Rectangle { x: root.selectionX + root.selectionWidth; y: root.selectionY; width: root.width - x; height: root.selectionHeight; color: "#99000000" }
    Rectangle {
        x: root.selectionX; y: root.selectionY
        width: root.selectionWidth; height: root.selectionHeight
        color: "transparent"; border.width: 1; border.color: Theme.colors.primary
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) { root.cancelled(); return; }
            root.startX = root.clampX(mouse.x); root.startY = root.clampY(mouse.y);
            root.cropLeft = root.startX; root.cropTop = root.startY;
            root.cropRight = root.startX; root.cropBottom = root.startY;
        }
        onPositionChanged: mouse => {
            if (!pressed || pressedButtons & Qt.RightButton) return;
            root.cropRight = root.clampX(mouse.x); root.cropBottom = root.clampY(mouse.y);
        }
        onReleased: mouse => {
            if (mouse.button !== Qt.LeftButton) return;
            const x = root.selectionX, y = root.selectionY, w = root.selectionWidth, h = root.selectionHeight;
            root.cropLeft = x; root.cropTop = y; root.cropRight = x + w; root.cropBottom = y + h;
            if (!root.editable && w >= 1 && h >= 1) root.selected();
        }
    }
    Repeater {
        model: root.editable ? [ [0,0], [0.5,0], [1,0], [0,0.5], [1,0.5], [0,1], [0.5,1], [1,1] ] : []
        delegate: Rectangle {
            id: handle
            required property var modelData
            x: root.selectionX + modelData[0] * root.selectionWidth - width / 2
            y: root.selectionY + modelData[1] * root.selectionHeight - height / 2
            width: 10; height: 10; radius: 2
            color: Theme.colors.primary
            border.color: Theme.colors.base; border.width: 1
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.SizeAllCursor
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const point = mapToItem(root, mouse.x, mouse.y);
                    const x = root.clampX(point.x), y = root.clampY(point.y);
                    if (handle.modelData[0] === 0) root.cropLeft = Math.min(x, root.cropRight - 1);
                    if (handle.modelData[0] === 1) root.cropRight = Math.max(x, root.cropLeft + 1);
                    if (handle.modelData[1] === 0) root.cropTop = Math.min(y, root.cropBottom - 1);
                    if (handle.modelData[1] === 1) root.cropBottom = Math.max(y, root.cropTop + 1);
                }
            }
        }
    }
}
