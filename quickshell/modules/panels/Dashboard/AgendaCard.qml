import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Upcoming events from today, in start order. Clicking one opens it in Google
// Calendar.
Rectangle {
    id: root

    readonly property var upcoming: SendaCalendar.upcomingEvents(20)

    function startOfDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }

    function dayLabel(event) {
        const date = new Date(event.when);
        const days = Math.round((root.startOfDay(date) - root.startOfDay(new Date())) / 86400000);
        if (days === 0) return "Hoy";
        if (days === 1) return "Mañana";
        return Qt.formatDate(date, "ddd d MMM");
    }

    function timeLabel(event) {
        return event.allDay ? "Todo el día" : Qt.formatTime(new Date(event.start), "HH:mm");
    }

    radius: Theme.rounding.normal
    color: Theme.colors.surface
    border.width: 1
    border.color: Theme.colors.surfaceVariant

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8

        Text {
            text: "PRÓXIMOS EVENTOS"
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        Text {
            Layout.fillWidth: true
            visible: SendaCalendar.status !== "ready"
            text: {
                if (SendaCalendar.status === "disconnected") return "Conecta tu cuenta de Google para ver tus eventos.";
                if (SendaCalendar.status === "error") return SendaCalendar.message;
                return "Cargando eventos…";
            }
            color: SendaCalendar.status === "error" ? Theme.colors.warning : Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: 11
            wrapMode: Text.WordWrap

            MouseArea {
                anchors.fill: parent
                enabled: SendaCalendar.status === "disconnected"
                cursorShape: Qt.PointingHandCursor
                onClicked: OverlayService.setCurrentPanel("settings")
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SendaCalendar.status === "ready" && root.upcoming.length === 0
            text: "No hay eventos próximos"
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: 11
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.upcoming

            delegate: Rectangle {
                required property var modelData

                width: ListView.view.width
                implicitHeight: row.implicitHeight + 8
                radius: Theme.rounding.small
                color: eventMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                RowLayout {
                    id: row
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    ColumnLayout {
                        Layout.preferredWidth: 78
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: root.dayLabel(modelData)
                            color: Theme.colors.primary
                            font.family: Theme.font.overlay.family
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.timeLabel(modelData)
                            color: Theme.colors.overlay
                            font.family: Theme.font.overlay.family
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: Theme.colors.text
                        font.family: Theme.font.base.family
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                MouseArea {
                    id: eventMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SendaCalendar.openEvent(modelData)
                }
            }
        }
    }
}
