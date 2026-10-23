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
        { label: "Apariencia" },
        { label: "Barra" },
        { label: "Calendario" },
        { label: "Tiempo" },
        { label: "Dictado" },
        { label: "Actualización" }
    ]
    property int currentSection: 0

    onVisibleChanged: {
        if (visible) {
            SendaSettings.refresh();
            SendaSttSettings.refresh();
        }
    }

    // The update notice in the bar opens this panel on the update section.
    Connections {
        target: SendaUpdate

        function onOpenRequested() {
            root.currentSection = root.sections.findIndex(section => section.label === "Actualización");
        }
    }

    // Same card style as the dashboard and the control center.
    component SettingsCard: Rectangle {
        radius: Theme.rounding.normal
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.surfaceVariant
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        SettingsCard {
            // Fixed at 22% of the window, so the sections never take over the content.
            Layout.preferredWidth: root.width * 0.22
            Layout.minimumWidth: root.width * 0.22
            Layout.maximumWidth: root.width * 0.22
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
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
                        required property var modelData
                        required property int index

                        readonly property bool selected: root.currentSection === index

                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: Theme.rounding.small
                        color: selected ? Theme.colors.surfaceVariant
                            : sectionMouse.containsMouse ? Qt.rgba(Theme.colors.surfaceVariant.r, Theme.colors.surfaceVariant.g, Theme.colors.surfaceVariant.b, 0.5)
                            : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            text: modelData.label
                            color: parent.selected ? Theme.colors.primary : Theme.colors.text
                            font.family: Theme.font.base.family
                            font.pixelSize: Theme.scaled(13)
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
                anchors.margins: 18
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

                Text {
                    Layout.fillWidth: true
                    visible: root.sections[root.currentSection]?.label !== "Barra" && SendaSettings.notice !== ""
                    text: SendaSettings.notice
                    color: SendaSettings.noticeIsError ? Theme.colors.warning : Theme.colors.success
                    font.family: Theme.font.overlay.family
                    font.pixelSize: Theme.scaled(12)
                    wrapMode: Text.WordWrap
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
                    }

                    UpdateSettingsPage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
