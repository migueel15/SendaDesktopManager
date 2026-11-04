import QtQuick
import Quickshell

import qs.common

Rectangle {
    id: root

    width: 100
    height: 175

    color: Theme.card.fill
    radius: Theme.card.radius

    border.width: Theme.card.borderWidth
    border.color: Theme.card.borderColor

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
                    font.pixelSize: Theme.scaled(50)
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
                    font.pixelSize: Theme.scaled(50)
                    font.weight: Theme.font.title.weight
                    color: Theme.colors.text
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                text: {
                    return String(Theme.locale.toString(systemClock.date, "MMM dd"));
                }

                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(15)
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
