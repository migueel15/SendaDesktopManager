import QtQuick

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

    readonly property int arcHeight: 12
    readonly property var arcSteps: [...Array(31).keys()]

    readonly property var timedEvents: SendaCalendar.eventsOn(root.today).filter(event => !event.allDay)

    // Clamps to the day, so an event or the marker never leaves the line.
    function positionOf(time) {
        const fraction = (time - root.dayStart) / (root.dayEnd - root.dayStart);
        return Math.max(0, Math.min(1, fraction)) * root.width;
    }

    function clock(time) {
        return Qt.formatTime(new Date(time), "HH:mm");
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
        anchors.topMargin: 16
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

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: SendaCalendar.openEvent(modelData)
            }
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
        font.pixelSize: 10
    }

    Text {
        anchors.right: parent.right
        y: track.y + 6
        text: "24:00"
        color: Theme.colors.overlay
        font.family: Theme.font.overlay.family
        font.pixelSize: 10
    }

    Text {
        x: Math.max(0, Math.min(root.width - implicitWidth, root.positionOf(root.sunriseTime) - implicitWidth / 2))
        y: track.y + 6
        visible: root.sunKnown
        text: root.clock(root.sunriseTime)
        color: Theme.colors.warning
        font.family: Theme.font.overlay.family
        font.pixelSize: 10
    }

    Text {
        x: Math.max(0, Math.min(root.width - implicitWidth, root.positionOf(root.sunsetTime) - implicitWidth / 2))
        y: track.y + 6
        visible: root.sunKnown
        text: root.clock(root.sunsetTime)
        color: Theme.colors.warning
        font.family: Theme.font.overlay.family
        font.pixelSize: 10
    }
}
