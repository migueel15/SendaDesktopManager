pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

Scope {
    Variants {
        model: ScreenshotService.frozen ? ScreenshotService.frames : []
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData.screen
            visible: ScreenshotService.frozen && ScreenshotService.readyFrames === ScreenshotService.frames.length
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "senda-screenshot"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            onVisibleChanged: if (visible) selection.forceActiveFocus()
            color: "black"
            Image {
                id: frozenImage
                anchors.fill: parent
                source: "file://" + encodeURI(window.modelData.path)
                fillMode: Image.Stretch
                cache: false
                onStatusChanged: {
                    if (status === Image.Ready) ScreenshotService.readyFrames++;
                    else if (status === Image.Error) ScreenshotService.fail("No se pudo cargar la imagen del monitor");
                }
            }
            CropSelection {
                id: selection
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: ScreenshotService.cleanup()
                onCancelled: ScreenshotService.cleanup()
                onSelected: {
                    const sx = frozenImage.sourceSize.width / width, sy = frozenImage.sourceSize.height / height;
                    const x = Math.floor(selectionX * sx), y = Math.floor(selectionY * sy);
                    const right = Math.min(frozenImage.sourceSize.width, Math.ceil((selectionX + selectionWidth) * sx));
                    const bottom = Math.min(frozenImage.sourceSize.height, Math.ceil((selectionY + selectionHeight) * sy));
                    ScreenshotService.crop(window.modelData.path, x, y, right - x, bottom - y, false, true);
                }
            }
        }
    }
    ScreenshotEditor {}
}
