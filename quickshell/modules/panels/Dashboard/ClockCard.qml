import QtQuick
import Quickshell

import qs.common

Rectangle {
    id: root

    width: 100
    height: 175

    color: Theme.colors.surface
    radius: Theme.rounding.normal

    border.width: 1
    border.color: Theme.colors.surfaceVariant

    Column {
        anchors.centerIn: parent

        Column {
            spacing: -10
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    text: {
                        return String(systemClock?.date.getHours()).padStart(2, "0");
                    }
                    font.family: Theme.font.title.family
                    font.pixelSize: 50
                    font.weight: Theme.font.title.weight
                    color: Theme.colors.text
                }
            }
            Row {

                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    text: {
                        return String(systemClock?.date.getMinutes()).padStart(2, "0");
                    }

                    font.family: Theme.font.title.family
                    font.pixelSize: 50
                    font.weight: Theme.font.title.weight
                    color: Theme.colors.text
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                text: {
                    return String(Qt.formatDate(systemClock.date, "MMM dd"));
                }

                font.family: Theme.font.title.family
                font.pixelSize: 15
                font.weight: Theme.font.title.weight
                color: Theme.colors.overlay
            }
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }
}
