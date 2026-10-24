pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

import qs.common
import qs.services

Rectangle {
    id: root

    required property string screenName

    color: Theme.colors.base
    clip: true

    property bool initialized: false
    property var front: first
    readonly property var back: front === first ? second : first
    property var pending: null
    property bool transitioning: false
    property string transitionType: "none"
    property real progress: 0
    property point origin: Qt.point(width / 2, height / 2)
    readonly property real radius: Math.hypot(Math.max(Math.abs(origin.x), Math.abs(width - origin.x)),
        Math.max(Math.abs(origin.y), Math.abs(height - origin.y))) + 2

    function fillMode(resize) {
        switch (resize) {
        case "fit": return Image.PreserveAspectFit;
        case "stretch": return Image.Stretch;
        case "none": return Image.Pad;
        default: return Image.PreserveAspectCrop;
        }
    }

    function imageUrl(path) {
        // Encode local paths so spaces, '#' and '%' remain filename characters.
        return path.startsWith("/") ? "file://" + path.split("/").map(encodeURIComponent).join("/") : path;
    }

    function refresh() {
        if (!initialized)
            return;
        if (transitioning)
            finish();
        const request = WallpaperService.current(screenName);
        // Cancel an in-flight decode before installing the newest request.
        pending = null;
        back.source = "";
        if (!request.path) {
            front.source = "";
            return;
        }
        pending = request;
        back.fillMode = fillMode(request.resize);
        back.source = imageUrl(request.path);
        imageStatusChanged(back);
    }

    function imageStatusChanged(frame) {
        if (!pending || transitioning || frame !== back)
            return;
        if (frame.status === Image.Error) {
            console.warn("WallpaperView: could not load wallpaper for", screenName, pending.path);
            pending = null;
            frame.source = "";
        } else if (frame.status === Image.Ready) {
            begin();
        }
    }

    function begin() {
        const transition = pending.transition;
        const choices = ["fade", "wipe", "wave", "grow", "center", "any", "outer"];
        transitionType = transition.type === "random"
            ? choices[Math.floor(Math.random() * choices.length)] : transition.type;
        const pos = transition.pos;
        origin = transitionType === "any" ? Qt.point(Math.round(Math.random() * width), Math.round(Math.random() * height))
            : transitionType === "center" || !pos ? Qt.point(Math.round(width / 2), Math.round(height / 2))
            : Qt.point(Math.round(pos.x), Math.round(height - pos.y));
        progress = 0;
        transitioning = true;
        if (transitionType === "none" || transition.durationMs === 0) {
            finish();
            return;
        }
        animation.duration = transition.durationMs;
        animation.easing.bezierCurve = transition.bezier.concat([1, 1]);
        animation.start();
    }

    function finish() {
        // stop() does not emit finished(); interruption commits the ready frame.
        animation.stop();
        const old = front;
        front = back;
        transitioning = false;
        pending = null;
        old.source = "";
        progress = 0;
    }

    // A diagonal half-plane x + y <= edge; wave perturbs its boundary.
    // The extra margin keeps both endpoints fully outside the viewport.
    function sweepPoints() {
        const amplitude = transitionType === "wave" ? Math.min(width, height) * 0.04 : 0;
        const margin = amplitude + 2;
        const edge = progress * (width + height + 2 * margin) - margin;
        const points = [Qt.point(-margin, -margin)];
        for (let i = 0; i <= 64; i++) {
            const y = -margin + (height + 2 * margin) * i / 64;
            const wave = amplitude * Math.sin(y / Math.max(1, height) * Math.PI * 6);
            points.push(Qt.point(edge - y + wave, y));
        }
        points.push(Qt.point(-height - 2 * margin, height + margin));
        points.push(points[0]);
        return points;
    }

    onScreenNameChanged: refresh()
    Component.onCompleted: {
        initialized = true;
        refresh();
    }

    Connections {
        target: WallpaperService
        function onChanged(screenName: string) {
            if (screenName === "" || screenName === root.screenName)
                root.refresh();
        }
    }

    NumberAnimation {
        id: animation
        target: root
        property: "progress"
        from: 0
        to: 1
        easing.type: Easing.BezierSpline
        onFinished: root.finish()
    }

    // Each frame includes the base color, so fit/pad never show the old image
    // through the new letterboxing. Swapping frames avoids another decode.
    component WallpaperFrame: Rectangle {
        id: frame

        property alias source: image.source
        property alias status: image.status
        property alias fillMode: image.fillMode

        anchors.fill: parent
        color: Theme.colors.base
        z: root.front === frame ? 0 : 1
        visible: source.toString() !== "" && (root.front === frame || root.transitioning)
        opacity: root.front !== frame && root.transitioning && root.transitionType === "fade" ? root.progress : 1
        layer.enabled: root.front !== frame && root.transitioning && root.transitionType !== "fade"
        layer.effect: OpacityMask {
            maskSource: transitionMask
            invert: root.transitionType === "outer"
        }

        Image {
            id: image
            anchors.fill: parent
            asynchronous: true
            cache: false
            sourceSize: Qt.size(Math.round(root.width), Math.round(root.height))
            onStatusChanged: root.imageStatusChanged(frame)
        }
    }

    WallpaperFrame { id: first }
    WallpaperFrame { id: second }

    Item {
        id: transitionMask
        anchors.fill: parent
        visible: false

        readonly property bool sweep: root.transitionType === "wipe" || root.transitionType === "wave"
        readonly property real circleRadius: root.radius * (root.transitionType === "outer" ? 1 - root.progress : root.progress)

        Rectangle {
            visible: !transitionMask.sweep
            x: Math.round(root.origin.x - transitionMask.circleRadius)
            y: Math.round(root.origin.y - transitionMask.circleRadius)
            width: Math.ceil(transitionMask.circleRadius * 2)
            height: width
            radius: width / 2
            color: "white"
        }

        Shape {
            anchors.fill: parent
            visible: transitionMask.sweep
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: "white"
                PathPolyline {
                    path: root.sweepPoints()
                }
            }
        }
    }
}
