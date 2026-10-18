import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.components
import qs.services

// Settings window with a sidebar of sections. Every change goes through the
// senda CLI. Opened with `senda settings` or from the dashboard.
SendaPanel {
    id: root
    name: "settings"

    padding: 16
    targetWidth: 680
    targetHeight: 520

    targetX: parent.width / 2 - root.width / 2
    targetY: 45

    // Sidebar entries. Each one needs a page in the StackLayout below, in the
    // same position.
    readonly property var sections: [
        { label: "Calendario" },
        { label: "Tiempo" }
    ]
    property int currentSection: 0

    onVisibleChanged: {
        if (visible) {
            SendaSettings.refresh();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 16

        ColumnLayout {
            Layout.preferredWidth: 170
            Layout.fillHeight: true
            spacing: 4

            Text {
                Layout.bottomMargin: 10
                text: "Ajustes"
                color: Theme.colors.text
                font.family: Theme.font.title.family
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            Repeater {
                model: root.sections

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    readonly property bool selected: root.currentSection === index

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Theme.rounding.small
                    color: selected ? Theme.colors.surfaceVariant : sectionMouse.containsMouse ? Theme.colors.surface : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        text: modelData.label
                        color: parent.selected ? Theme.colors.primary : Theme.colors.text
                        font.family: Theme.font.base.family
                        font.pixelSize: 13
                        font.weight: parent.selected ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        id: sectionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentSection = index
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            SettingsButton {
                Layout.fillWidth: true
                label: "Cerrar"
                onClicked: OverlayService.closeCurrentPanel()
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.colors.surfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                visible: SendaSettings.notice !== ""
                text: SendaSettings.notice
                color: SendaSettings.noticeIsError ? Theme.colors.warning : Theme.colors.success
                font.family: Theme.font.overlay.family
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentSection

                CalendarSettingsPage {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                WeatherSettingsPage {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
