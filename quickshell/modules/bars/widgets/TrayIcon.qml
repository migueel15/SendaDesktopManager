import QtQuick
import QtQuick.Window

// Normalize the painted bounds, not the transparent canvas supplied by the app.
// Canvas also accepts Quickshell's image providers (theme icons and SNI pixmaps).
Item {
    id: root

    property string source: ""
    property string fallbackSource: ""
    property int iconSize: 18
    readonly property bool usingFallback: !canvas.hasContent || picture.status !== Image.Ready
    property int retryCount: 0
    property int loadGeneration: 0
    property bool usingFallbackSource: false
    readonly property string activeSource: usingFallbackSource ? fallbackSource : source
    // Absolute IconName paths need no theme lookup. Going through QIcon caches
    // file contents across retries, even when Image.cache is false.
    readonly property string resolvedSource: {
        if (activeSource.startsWith("image://icon//")) {
            let path = activeSource.substring("image://icon/".length);
            const query = path.indexOf("?path=");
            if (query !== -1)
                path = path.substring(0, query);
            return "file://" + path;
        }
        return activeSource;
    }
    // Both dimensions must be valid for Quickshell image:// providers. Passing
    // -1 makes them silently choose their 100x100 default instead of our size.
    readonly property bool providerSource: resolvedSource.startsWith("image://")
    readonly property real pixelRatio: Screen.devicePixelRatio || 1
    // Request enough pixels for the cropped image and downsample on the GPU.
    // A 64px minimum also selects larger SNI/theme variants instead of 16/22px
    // assets when the application publishes more than one resolution.
    readonly property int decodeWidth: Math.min(512, Math.max(64, Math.ceil(picture.width * pixelRatio * 2)))
    readonly property int decodeHeight: Math.min(512, Math.max(64, Math.ceil(picture.height * pixelRatio * 2)))
    implicitWidth: iconSize
    implicitHeight: iconSize
    clip: true

    function reload() {
        retry.stop();
        retryCount = 0;
        usingFallbackSource = false;
        canvas.loadSource();
    }

    function tryFallbackSource() {
        if (usingFallbackSource || fallbackSource === "" || fallbackSource === source)
            return false;
        usingFallbackSource = true;
        Qt.callLater(canvas.loadSource);
        return true;
    }

    onSourceChanged: reload()
    onFallbackSourceChanged: reload()
    onVisibleChanged: if (visible && usingFallback) reload()

    // Drawn locally: works even with a missing icon theme or broken image provider.
    Rectangle {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        visible: root.usingFallback
        radius: 3
        color: "#313244"
        border.color: "#cdd6f4"
        border.width: 1
        Rectangle {
            x: 3
            y: 4
            width: parent.width - 6
            height: 2
            color: "#cdd6f4"
        }
        Rectangle {
            x: 3
            y: 9
            width: 4
            height: 4
            color: "#89b4fa"
        }
    }

    // Black tray artwork otherwise disappears on the dark bar.
    Rectangle {
        anchors.fill: parent
        radius: 3
        color: "#cdd6f4"
        visible: !root.usingFallback && canvas.darkContent
    }

    // Canvas measures only. Image draws a larger raster with mipmap filtering;
    // drawing it directly into an 18px Canvas loses fine strokes.
    Image {
        id: picture
        source: canvas.loadedSource
        sourceSize: Qt.size(root.decodeWidth, root.providerSource ? root.decodeHeight : -1)
        cache: false
        asynchronous: false
        smooth: true
        mipmap: true
        visible: !root.usingFallback
        x: canvas.imageRect.x
        y: canvas.imageRect.y
        width: canvas.imageRect.width
        height: canvas.imageRect.height
        onStatusChanged: {
            if (status === Image.Ready && canvas.hasContent)
                retry.stop();
            else if (status === Image.Error)
                root.tryFallbackSource();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        smooth: true
        antialiasing: true
        property string loadedSource: ""
        property bool hasContent: false
        property bool darkContent: false
        property rect imageRect: Qt.rect(0, 0, root.width, root.height)

        function loadSource() {
            hasContent = false;
            if (!available)
                return;
            if (loadedSource !== "")
                unloadImage(loadedSource);
            loadedSource = "";
            // Let Image actually release the old pixmap, even if the app reused
            // its URL. Coalesce multiple notifications into the latest source.
            Qt.callLater(finishLoad);
        }

        function finishLoad() {
            if (!available)
                return;
            root.loadGeneration += 1;
            const source = root.resolvedSource;
            // Canvas has its own image cache. A local-file query forces a new
            // read without changing the filesystem path or any SNI provider URL.
            loadedSource = source.startsWith("file:")
                ? source + (source.indexOf("?") === -1 ? "?" : "&") + "sendaTrayReload=" + root.loadGeneration
                : source;
            if (loadedSource !== "") {
                // Ask for a good raster before cropping; small originals still upscale.
                loadImage(loadedSource, Qt.size(128, root.providerSource ? 128 : -1));
                retry.restart();
            }
            requestPaint();
        }

        onAvailableChanged: if (available) loadSource()
        onImageLoaded: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            hasContent = false;
            if (loadedSource === "" || !isImageLoaded(loadedSource))
                return;
            try {
                const pixels = ctx.createImageData(loadedSource);
                const w = pixels.width;
                const h = pixels.height;
                let left = w, top = h, right = -1, bottom = -1;
                let light = 0, weight = 0;
                let missingPixels = 0;
                for (let y = 0; y < h; ++y) {
                    for (let x = 0; x < w; ++x) {
                        const i = (y * w + x) * 4;
                        const alpha = pixels.data[i + 3];
                        // Quickshell returns a black/magenta checkerboard with
                        // Image.Ready on provider failure, not Image.Error.
                        if (root.providerSource && alpha === 255) {
                            const magenta = (x < w / 2) !== (y < h / 2);
                            if (pixels.data[i] === (magenta ? 217 : 0)
                                    && pixels.data[i + 1] === 0
                                    && pixels.data[i + 2] === (magenta ? 216 : 0))
                                missingPixels += 1;
                        }
                        // Ignore nearly invisible pixels and faint padding/shadows.
                        if (alpha < 16)
                            continue;
                        left = Math.min(left, x);
                        top = Math.min(top, y);
                        right = Math.max(right, x);
                        bottom = Math.max(bottom, y);
                        light += alpha * (0.2126 * pixels.data[i] + 0.7152 * pixels.data[i + 1] + 0.0722 * pixels.data[i + 2]);
                        weight += alpha;
                    }
                }
                if (right < left || bottom < top || missingPixels === w * h) {
                    root.tryFallbackSource();
                    return;
                }
                const sw = right - left + 1;
                const sh = bottom - top + 1;
                const scale = Math.min(width / sw, height / sh);
                const dw = sw * scale;
                const dh = sh * scale;
                imageRect = Qt.rect((width - dw) / 2 - left * scale, (height - dh) / 2 - top * scale, w * scale, h * scale);
                darkContent = light / weight < 65;
                hasContent = true;
                if (picture.status === Image.Ready)
                    retry.stop();
            } catch (error) {
                console.warn("Tray icon normalization failed:", loadedSource, error);
            }
        }
    }

    // Fast startup recovery, then a low-frequency retry only for failed images.
    // An app can take longer than the original 31-second retry budget to be ready.
    Timer {
        id: retry
        interval: Math.min(30000, 1000 * Math.pow(2, root.retryCount))
        onTriggered: {
            if (root.usingFallback) {
                root.retryCount = Math.min(5, root.retryCount + 1);
                canvas.loadSource();
            }
        }
    }
}
