import Quickshell
import QtQuick

import qs.common
import qs.services

Rectangle {
    id: clockBackground

    property string screenName: ""

    readonly property bool open: OverlayService.isOpen("dashboard")

    // Same hover pill as the other bar buttons; stays lit while the dashboard is open.
    color: clockMouse.containsMouse || open ? Theme.colors.surfaceVariant : "transparent"
    radius: Theme.rounding.normal
    height: parent.height * 0.8
    width: clockRow.implicitWidth + 24

    anchors.centerIn: parent

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                OverlayService.togglePanel("dashboard", clockBackground.screenName);
            } else if (event.button === Qt.RightButton) {
                clockText.isPrimary = !clockText.isPrimary;
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Primary: weekday in Humo and the time in Bruma. Secondary: the full date.
    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: clockText.isPrimary
            text: {
                const weekDay = clock.date.toLocaleString(Theme.locale, "dddd");
                return weekDay.charAt(0).toUpperCase() + weekDay.slice(1);
            }
            color: Theme.colors.overlay
            font: Theme.font.base
        }

        Text {
            id: clockText

            property bool isPrimary: true

            text: {
                if (isPrimary)
                    return clock.date.toLocaleString(Theme.locale, "hh:mm");
                const month = clock.date.toLocaleString(Theme.locale, "MMMM");
                return `${clock.date.toLocaleString(Theme.locale, "dd")} ${month.charAt(0).toUpperCase() + month.slice(1)} ${clock.date.toLocaleString(Theme.locale, "yyyy")}`;
            }
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: Theme.font.base.pixelSize
            font.weight: isPrimary ? Font.DemiBold : Font.Normal
        }
    }
}
