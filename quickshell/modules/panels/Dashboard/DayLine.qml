import QtQuick
import QtQuick.Shapes

import qs.common
import qs.services

// The whole day as a line from 00:00 to 24:00. A dotted arc rises between
// sunrise and sunset, the sun's path over the day. Dots mark sunrise, sunset
// and today's timed events, and a marker shows the current time. Without
// sunrise and sunset from the weather service, only the line is drawn.
Item {
    id: root

    property date now: new Date()
    readonly property date today: new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate())
    readonly property real dayStart: root.today.getTime()
    readonly property real dayEnd: new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate() + 1).getTime()

    readonly property bool sunKnown: !!SendaWeather.current && !!SendaWeather.current.sunrise && !!SendaWeather.current.sunset
    readonly property real sunriseTime: root.sunKnown ? new Date(SendaWeather.current.sunrise).getTime() : root.dayStart
    readonly property real sunsetTime: root.sunKnown ? new Date(SendaWeather.current.sunset).getTime() : root.dayStart

    readonly property int arcHeight: 18
    readonly property var arcSteps: [...Array(31).keys()]

    readonly property var timedEvents: SendaCalendar.eventsOn(root.today).filter(event => !event.allDay)

    // Clamps to the day, so an event or the marker never leaves the line.
    function positionOf(time) {
        const fraction = (time - root.dayStart) / (root.dayEnd - root.dayStart);
        return Math.max(0, Math.min(1, fraction)) * root.width;
    }

    function clock(time) {
        return Theme.locale.toString(new Date(time), "HH:mm");
    }

    // Event under the pointer and its horizontal center, for the tooltip.
    property var hoveredEvent: null
    property real hoveredX: 0
    // A dot opens its tooltip within openRadius and the tooltip closes only
    // beyond closeRadius, so small movements around the dot keep it open.
    readonly property real openRadius: 6
    readonly property real closeRadius: 18

    // Center of a dot, in this item's coordinates.
    function dotCenter(event) {
        return { x: root.positionOf(new Date(event.start).getTime()), y: track.y + 1 };
    }

    // Opens, keeps or closes the tooltip for a pointer at (x, y).
    function updateHover(x, y) {
        if (root.hoveredEvent) {
            const current = root.dotCenter(root.hoveredEvent);
            if (Math.hypot(x - current.x, y - current.y) <= root.closeRadius) {
                return;
            }
            root.hoveredEvent = null;
        }

        let nearest = null;
        let best = root.openRadius;
        for (const event of root.timedEvents) {
            const center = root.dotCenter(event);
            const distance = Math.hypot(x - center.x, y - center.y);
            if (distance <= best) {
                best = distance;
                nearest = event;
            }
        }
        if (nearest) {
            root.hoveredEvent = nearest;
            root.hoveredX = root.dotCenter(nearest).x;
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 20
        height: 2
        radius: 1
        color: Theme.colors.surfaceVariant
    }

    // Dotted arc from sunrise to sunset. Every other point is drawn, so it reads
    // as dots rather than a line, and each one sits higher toward midday.
    Repeater {
        model: root.sunKnown ? root.arcSteps : []

        delegate: Rectangle {
            required property int modelData

            readonly property real fraction: modelData / (root.arcSteps.length - 1)
            readonly property real time: root.sunriseTime + fraction * (root.sunsetTime - root.sunriseTime)

            x: root.positionOf(time) - width / 2
            y: track.y - height / 2 - Math.sin(Math.PI * fraction) * root.arcHeight
            width: 2
            height: 2
            radius: 1
            color: Theme.colors.overlay
            visible: modelData % 2 === 0
        }
    }

    Rectangle {
        width: 6
        height: 6
        radius: 3
        color: Theme.colors.warning
        x: root.positionOf(root.sunriseTime) - width / 2
        y: track.y - 2
        visible: root.sunKnown
    }

    Rectangle {
        width: 6
        height: 6
        radius: 3
        color: Theme.colors.warning
        x: root.positionOf(root.sunsetTime) - width / 2
        y: track.y - 2
        visible: root.sunKnown
    }

    Repeater {
        model: root.timedEvents

        delegate: Rectangle {
            required property var modelData

            readonly property real eventTime: new Date(modelData.start).getTime()

            x: root.positionOf(eventTime) - width / 2
            y: track.y - 2
            width: 6
            height: 6
            radius: 3
            color: Theme.colors.secondary

        }
    }

    Rectangle {
        width: 10
        height: 10
        radius: 5
        color: Theme.colors.primary
        x: root.positionOf(root.now.getTime()) - width / 2
        y: track.y - 4
    }

    Text {
        x: 0
        y: track.y + 6
        text: "00:00"
        color: Theme.colors.overlay
        font.family: Theme.font.overlay.family
        font.pixelSize: Theme.scaled(10)
    }

    Text {
        anchors.right: parent.right
        y: track.y + 6
        text: "24:00"
        color: Theme.colors.overlay
        font.family: Theme.font.overlay.family
        font.pixelSize: Theme.scaled(10)
    }

    // Sunrise and sunset: an icon above each time, placed at the sun's dot.
    Column {
        x: Math.max(0, Math.min(root.width - width, root.positionOf(root.sunriseTime) - width / 2))
        y: track.y + 6
        visible: root.sunKnown
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰖜"
            color: Theme.colors.warning
            font.family: Theme.font.title.family
            font.pixelSize: Theme.scaled(12)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.clock(root.sunriseTime)
            color: Theme.colors.warning
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(10)
        }
    }

    Column {
        x: Math.max(0, Math.min(root.width - width, root.positionOf(root.sunsetTime) - width / 2))
        y: track.y + 6
        visible: root.sunKnown
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰖛"
            color: Theme.colors.warning
            font.family: Theme.font.title.family
            font.pixelSize: Theme.scaled(12)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.clock(root.sunsetTime)
            color: Theme.colors.warning
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(10)
        }
    }

    // One area over the whole line tracks the pointer, so the tooltip follows
    // the distance rules above. Clicking opens the event under the pointer.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.hoveredEvent ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPositionChanged: mouse => root.updateHover(mouse.x, mouse.y)
        onExited: root.hoveredEvent = null
        onClicked: {
            if (root.hoveredEvent) {
                SendaCalendar.openEvent(root.hoveredEvent);
            }
        }
    }

    // Tooltip for the event under the pointer: its start time and title.
    Rectangle {
        id: tooltip
        visible: root.hoveredEvent !== null
        z: 10
        width: tipRow.implicitWidth + 16
        height: tipRow.implicitHeight + 10
        x: Math.max(0, Math.min(root.width - width, root.hoveredX - width / 2))
        y: track.y - height - 8
        radius: Theme.rounding.small
        color: Theme.colors.background
        border.width: 1
        border.color: Theme.colors.surfaceVariant

        Row {
            id: tipRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: root.hoveredEvent ? root.clock(new Date(root.hoveredEvent.start).getTime()) : ""
                color: Theme.colors.primary
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(11)
                font.weight: Font.Bold
            }

            Text {
                width: Math.min(implicitWidth, 220)
                text: root.hoveredEvent ? root.hoveredEvent.title : ""
                color: Theme.colors.text
                font.family: Theme.font.base.family
                font.pixelSize: Theme.scaled(11)
                elide: Text.ElideRight
            }
        }
    }

    // Small pointer under the tooltip, aimed at the event dot.
    Shape {
        visible: tooltip.visible
        z: 10
        width: 12
        height: 6
        x: Math.max(tooltip.x + 6, Math.min(tooltip.x + tooltip.width - 18, root.hoveredX - 6))
        y: tooltip.y + tooltip.height - 1

        ShapePath {
            fillColor: Theme.colors.background
            strokeColor: Theme.colors.surfaceVariant
            strokeWidth: 1

            startX: 0
            startY: 0
            PathLine { x: 12; y: 0 }
            PathLine { x: 6; y: 6 }
            PathLine { x: 0; y: 0 }
        }
    }
}
