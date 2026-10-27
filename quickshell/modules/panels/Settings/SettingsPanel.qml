pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Settings window with a sidebar of sections. Configuration goes through the
// senda CLI; tray pins use TrayPins. Opened with `senda settings` or from the
// dashboard. The overlay hosts it in a SendaPanel shared with the dashboard.
Item {
    id: root

    // Height the content needs; the host panel gives it the dashboard width.
    readonly property real contentHeight: 520

    // Sidebar entries. Each one needs a page in the StackLayout below, in the
    // same position.
    readonly property var sections: [
        { label: "Apariencia", icon: "󰏘" },
        { label: "Barra", icon: "󰍜" },
        { label: "Widgets", icon: "󰕮" },
        { label: "Calendario", icon: "󰃭" },
        { label: "Tiempo", icon: "󰖐" },
        { label: "Dictado", icon: "󰍬" },
        { label: "Sistema", icon: "󰒓" },
        { label: "Actualización", icon: "󰚰" }
    ]
    property int currentSection: 0

    onVisibleChanged: {
        if (visible) {
            SendaSettings.refresh();
            SendaSttSettings.refresh();
            SendaHyprlandSettings.refresh();
        }
    }

    // The update notice in the bar opens this panel on the update section.
    Connections {
        target: SendaUpdate

        function onOpenRequested() {
            root.currentSection = root.sections.findIndex(section => section.label === "Actualización");
        }
    }

    Connections {
        target: SendaSettings
        function onNoticeChanged() { feedback.show(SendaSettings.notice, SendaSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(SendaSettings.notice, SendaSettings.noticeIsError); }
    }
    Connections {
        target: SendaSttSettings
        function onNoticeChanged() { feedback.show(SendaSttSettings.notice, SendaSttSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(SendaSttSettings.notice, SendaSttSettings.noticeIsError); }
    }

    Connections {
        target: SendaHyprlandSettings
        function onNoticeChanged() { feedback.show(SendaHyprlandSettings.notice, SendaHyprlandSettings.noticeIsError); }
        function onNoticeIsErrorChanged() { feedback.show(SendaHyprlandSettings.notice, SendaHyprlandSettings.noticeIsError); }
    }

    // Same card style as the dashboard and the control center.
    component SettingsCard: Rectangle {
        radius: Theme.rounding.normal
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.border
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacing.md

        SettingsCard {
            // Reserve room for the longest label at the active text scale.
            Layout.preferredWidth: Math.max(root.width * 0.24, Theme.scaled(145))
            Layout.minimumWidth: Math.max(root.width * 0.24, Theme.scaled(145))
            Layout.maximumWidth: Math.max(root.width * 0.24, Theme.scaled(145))
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing.md
                spacing: 4

                Text {
                    Layout.bottomMargin: 10
                    text: "Ajustes"
                    color: Theme.colors.text
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(18)
                    font.weight: Font.Bold
                }

                Repeater {
                    model: root.sections

                    delegate: Rectangle {
                        id: sectionEntry
                        required property var modelData
                        required property int index

                        readonly property bool selected: root.currentSection === index

                        Layout.fillWidth: true
                        implicitHeight: Theme.scaled(24) + Theme.spacing.md
                        radius: Theme.rounding.small
                        color: selected ? Theme.colors.selection
                            : sectionMouse.containsMouse ? Theme.colors.surfaceVariant : Theme.colors.surface

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            text: sectionEntry.modelData.icon
                            font: Theme.font.icon
                            color: parent.selected ? Theme.colors.primary : Theme.colors.overlay
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacing.xl + Theme.spacing.md
                            text: sectionEntry.modelData.label
                            color: parent.selected ? Theme.colors.white : Theme.colors.text
                            font.family: Theme.font.base.family
                            font.pixelSize: Theme.scaled(13)
                            font.weight: parent.selected ? Font.Bold : Font.Normal
                        }

                        MouseArea {
                            id: sectionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentSection = sectionEntry.index
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                SettingsButton {
                    Layout.fillWidth: true
                    label: "Cerrar"
                    onClicked: OverlayService.closeOrGoBack()
                }
            }
        }

        SettingsCard {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing.lg
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    text: root.sections[root.currentSection]?.label ?? ""
                    color: Theme.colors.primary
                    font.family: Theme.font.title.family
                    font.pixelSize: Theme.scaled(16)
                    font.weight: Font.Bold
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentSection

                    AppearanceSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    BarSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    WidgetsSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    CalendarSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    WeatherSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    SttSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onOpenSystemRequested: root.currentSection = root.sections.findIndex(section => section.label === "Sistema")
                    }

                    SystemSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    UpdateSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
                SettingsStatus {
                    id: feedback
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.scaled(30)
                }
            }
        }
    }
}
