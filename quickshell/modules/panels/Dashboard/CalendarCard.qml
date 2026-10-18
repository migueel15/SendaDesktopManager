import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Month view with the events of the selected day. Weeks start on Monday and
// the grid always shows six weeks, so the layout never changes height.
Rectangle {
    id: root

    readonly property int visibleEvents: 5

    property date today: root.startOfDay(new Date())
    property date shownMonth: new Date(root.today.getFullYear(), root.today.getMonth(), 1)
    property date selectedDay: root.today

    readonly property date gridStart: new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth(), 1 - ((root.shownMonth.getDay() + 6) % 7))
    readonly property var selectedEvents: SendaCalendar.eventsOn(root.selectedDay)

    radius: Theme.rounding.normal
    color: Theme.colors.surface
    border.width: 1
    border.color: Theme.colors.surfaceVariant

    function startOfDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }

    function dayAt(index) {
        return new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index);
    }

    function sameDay(first, second) {
        return first.getFullYear() === second.getFullYear()
            && first.getMonth() === second.getMonth()
            && first.getDate() === second.getDate();
    }

    function capitalize(text) {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    // Asks for the shown month and its neighbours, which the grid can also show.
    function requestVisibleMonths() {
        const year = root.shownMonth.getFullYear();
        const month = root.shownMonth.getMonth();
        SendaCalendar.requestMonths([
            new Date(year, month - 1, 1),
            root.shownMonth,
            new Date(year, month + 1, 1)
        ]);
    }

    function moveMonth(offset) {
        root.shownMonth = new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth() + offset, 1);
    }

    function goToToday() {
        root.today = root.startOfDay(new Date());
        root.shownMonth = new Date(root.today.getFullYear(), root.today.getMonth(), 1);
        root.selectedDay = root.today;
    }

    onShownMonthChanged: root.requestVisibleMonths()

    onVisibleChanged: {
        if (visible) {
            root.today = root.startOfDay(new Date());
            root.requestVisibleMonths();
        }
    }

    Component.onCompleted: root.requestVisibleMonths()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "󰅁"
                    color: Theme.colors.primary
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(16)

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.moveMonth(-1)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.capitalize(Theme.locale.toString(root.shownMonth, "MMMM yyyy"))
                    color: Theme.colors.text
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(13)
                    font.weight: Font.Bold

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToToday()
                    }
                }
                Text {
                    text: "󰅂"
                    color: Theme.colors.primary
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(16)

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.moveMonth(1)
                    }
                }

            }

            RowLayout {
                Layout.fillWidth: true

                Repeater {
                    model: ["L", "M", "X", "J", "V", "S", "D"]

                    delegate: Text {
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.colors.overlay
                        font.family: Theme.font.overlay.family
                        font.pixelSize: Theme.scaled(10)
                        font.weight: Font.Bold
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2

                Repeater {
                    model: 42

                    delegate: Rectangle {
                        id: cell
                        required property int index

                        readonly property date day: root.dayAt(cell.index)
                        readonly property bool inMonth: cell.day.getMonth() === root.shownMonth.getMonth()
                        readonly property bool isToday: root.sameDay(cell.day, root.today)
                        readonly property bool isSelected: root.sameDay(cell.day, root.selectedDay)
                        readonly property bool hasEvents: SendaCalendar.eventsOn(cell.day).length > 0

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.rounding.small
                        color: cell.isSelected ? Theme.colors.surfaceVariant : "transparent"
                        border.width: cell.isToday ? 1 : 0
                        border.color: Theme.colors.primary

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            text: cell.day.getDate()
                            color: cell.isToday ? Theme.colors.primary : cell.inMonth ? Theme.colors.text : Theme.colors.overlay
                            opacity: cell.inMonth ? 1 : 0.45
                            font.family: Theme.font.overlay.family
                            font.pixelSize: Theme.scaled(11)
                            font.weight: cell.isToday ? Font.Bold : Font.Normal
                        }

                        Rectangle {
                            visible: cell.hasEvents
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.colors.secondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedDay = cell.day;
                                if (!cell.inMonth) {
                                    root.shownMonth = new Date(cell.day.getFullYear(), cell.day.getMonth(), 1);
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.colors.surfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.capitalize(Theme.locale.toString(root.selectedDay, "dddd d 'de' MMMM"))
                color: Theme.colors.primary
                font.family: Theme.font.title.family
                font.pixelSize: Theme.scaled(14)
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: SendaCalendar.status !== "ready" || !SendaCalendar.isLoaded(root.selectedDay)
                text: {
                    if (SendaCalendar.status === "disconnected") return "Conecta tu cuenta de Google para ver tus eventos.";
                    if (SendaCalendar.status === "error") return SendaCalendar.message;
                    return "Cargando eventos…";
                }
                color: SendaCalendar.status === "error" ? Theme.colors.warning : Theme.colors.overlay
                font.family: Theme.font.overlay.family
                font.pixelSize: Theme.scaled(11)
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
                visible: SendaCalendar.status === "ready" && SendaCalendar.isLoaded(root.selectedDay) && root.selectedEvents.length === 0
                text: "Sin eventos este día"
                color: Theme.colors.overlay
                font.family: Theme.font.overlay.family
                font.pixelSize: Theme.scaled(11)
            }

            Repeater {
                model: root.selectedEvents.slice(0, root.visibleEvents)

                delegate: Item {
                    id: eventItem
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: eventRow.implicitHeight

                    RowLayout {
                        id: eventRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 10

                        Text {
                            Layout.preferredWidth: 58
                            text: modelData.allDay ? "Todo el día" : Theme.locale.toString(new Date(modelData.start), "HH:mm")
                            color: Theme.colors.secondary
                            font.family: Theme.font.overlay.family
                            font.pixelSize: Theme.scaled(11)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: Theme.colors.text
                            font.family: Theme.font.base.family
                            font.pixelSize: Theme.scaled(12)
                            wrapMode: Text.WordWrap
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SendaCalendar.openEvent(eventItem.modelData)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.selectedEvents.length > root.visibleEvents
                text: `+${root.selectedEvents.length - root.visibleEvents} más`
                color: Theme.colors.overlay
                font.family: Theme.font.overlay.family
                font.pixelSize: Theme.scaled(11)
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
