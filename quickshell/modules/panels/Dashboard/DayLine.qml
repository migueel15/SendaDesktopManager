import QtQuick

import qs.common
import qs.services

// Today as a line from sunrise to sunset. Each timed event is a dot at its
// start, and a marker moves along the line with the current time. Without
// sunrise and sunset from the weather service, the line covers the whole day.
Item {
    id: root

    property date now: new Date()
    readonly property date today: new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate())

    readonly property bool sunKnown: !!SendaWeather.current && !!SendaWeather.current.sunrise && !!SendaWeather.current.sunset
    readonly property real lineStart: root.sunKnown ? new Date(SendaWeather.current.sunrise).getTime() : root.today.getTime()
    readonly property real lineEnd: root.sunKnown ? new Date(SendaWeather.current.sunset).getTime() : root.today.getTime() + 86400000

    readonly property var timedEvents: SendaCalendar.eventsOn(root.today).filter(event => !event.allDay)

    function positionOf(time) {
        const fraction = (time - root.lineStart) / (root.lineEnd - root.lineStart);
        return Math.max(0, Math.min(1, fraction)) * root.width;
    }

    function inLine(time) {
        return time >= root.lineStart && time <= root.lineEnd;
    }

    function clock(time) {
        return Qt.formatTime(new Date(time), "HH:mm");
    }

    // Says what the light is doing, so the line never shows up without context.
    readonly property string lightStatus: {
        if (!root.sunKnown) return "Sin datos de amanecer y atardecer";
        const current = root.now.getTime();
        if (current < root.lineStart) return `Noche · amanece a las ${root.clock(root.lineStart)}`;
        if (current > root.lineEnd) return "Noche · el sol ya se ha puesto";
        return `Luz · se pone a las ${root.clock(root.lineEnd)}`;
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        elide: Text.ElideRight
        text: root.lightStatus
        color: Theme.colors.text
        font.family: Theme.font.overlay.family
        font.pixelSize: 11
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 24
        height: 2
        radius: 1
        color: Theme.colors.surfaceVariant
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
            visible: root.inLine(eventTime)

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: SendaCalendar.openEvent(modelData)
            }
        }
    }

    Rectangle {
        id: marker
        width: 10
        height: 10
        radius: 5
        color: Theme.colors.primary
        x: root.positionOf(root.now.getTime()) - width / 2
        y: track.y - 4
        visible: root.inLine(root.now.getTime())
    }

    Text {
        anchors.left: parent.left
        anchors.top: track.bottom
        anchors.topMargin: 6
        visible: root.sunKnown
        text: root.clock(root.lineStart)
        color: Theme.colors.overlay
        font.family: Theme.font.overlay.family
        font.pixelSize: 10
    }

    Text {
        anchors.right: parent.right
        anchors.top: track.bottom
        anchors.topMargin: 6
        visible: root.sunKnown
        text: root.clock(root.lineEnd)
        color: Theme.colors.overlay
        font.family: Theme.font.overlay.family
        font.pixelSize: 10
    }
}
