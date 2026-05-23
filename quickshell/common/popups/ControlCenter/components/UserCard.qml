import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts

import qs.common
import qs.common.components

Rectangle {
    id: userCard

    property string uptime: ""

    width: parent.width
    color: Theme.colors.surface
    height: 60
    radius: 10

    // Add z-index to ensure menu appears on top
    z: 10

    function closeSystemMenu() {
        systemMenu.close();
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Rectangle {
            id: imageArea
            implicitWidth: imageArea.height
            color: "transparent"
            Layout.fillHeight: true
            Rectangle {
                id: image
                radius: 100
                anchors.fill: parent
                color: Theme.colors.overlay
                anchors.centerIn: parent
            }
        }

        Rectangle {
            implicitWidth: uptimeText.implicitWidth
            Layout.fillHeight: true
            color: "transparent"
            Column {

                anchors.centerIn: parent
                spacing: 1

                Text {
                    text: Quickshell.env("USER")
                    color: Theme.colors.text
                    font: Theme.font.title
                }
                Text {
                    id: uptimeText
                    text: userCard.uptime
                    font: Theme.font.overlay
                    color: Theme.colors.overlay

                    Process {
                        id: uptimeReader
                        command: ["uptime", "-p"]
                        running: true
                        stdout: StdioCollector {
                            onStreamFinished: userCard.uptime = this.text.trim()
                        }
                    }

                    Timer {
                        interval: 1000 * 60
                        running: true
                        repeat: true
                        onTriggered: uptimeReader.running = true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                IconButtom {
                    icon: ""
                    command: ["hyprlock"]
                }

                IconButtom {
                    icon: "󰂯"
                    command: ["blueberry"]
                }
                IconButtom {
                    icon: ""
                    onClick: () => systemMenu.toggle()
                }
            }
        }
    }

    // System menu popup
    SystemMenu {
        id: systemMenu
        anchors.top: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: 5
    }
}
