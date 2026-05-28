import Quickshell
import QtQuick

import qs.common
import qs.services

Rectangle {
    id: clockBackground

    color: Theme.colors.background
    height: parent.height
    width: clockText.width + 20

    anchors.centerIn: parent
    // layer.enabled: true
    // layer.effect: Shadow {
    //     color: ThemeManager.selectedTheme.colors.topbarColor
    // }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                OverlayService.setCurrentPanel("dashboard");
            } else if (event.button === Qt.RightButton) {
                clockText.isPrimary = !clockText.isPrimary;
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: clockText

        property bool isPrimary: true
        property string primaryFormat: {
            const weekDay = clock.date.toLocaleString(Qt.locale(), "dddd");
            const capitalizedWeekDay = weekDay.charAt(0).toUpperCase() + weekDay.slice(1);
            return capitalizedWeekDay + " " + clock.date.toLocaleString(Qt.locale(), "hh:mm");
        }
        property string secondaryFormat: {
            const month = clock.date.toLocaleString(Qt.locale(), "MMMM");
            const capitalizedMonth = month.charAt(0).toUpperCase() + month.slice(1);
            return `${clock.date.toLocaleString(Qt.locale(), "dd")} ${capitalizedMonth} ${clock.date.toLocaleString(Qt.locale(), "yyyy")}`;
        }
        // text: clock.date.toLocaleString(Qt.locale(), "hh:mm AP - dddd, dd MMMM yyyy")
        text: {
            isPrimary ? primaryFormat : secondaryFormat;
        }
        color: Theme.colors.text
        font: Theme.font.base
        anchors.centerIn: parent
    }
}
