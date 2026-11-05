import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick.Layouts

import qs.common
import qs.services
import qs.common.components

Rectangle {
    id: userCard

    property string uptime: ""
    signal powerMenuToggleRequested
    signal powerMenuCloseRequested

    width: parent.width
    color: Theme.card.fill
    height: 60
    radius: Theme.card.radius
    // Square while the power menu is attached below.
    bottomLeftRadius: attachedBelow ? 0 : Theme.card.radius
    bottomRightRadius: attachedBelow ? 0 : Theme.card.radius
    property bool attachedBelow: false
    border.width: 1
    border.color: Theme.colors.surfaceVariant
    z: 10

    function closeSystemMenu() {
        powerMenuCloseRequested();
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
            ClippingWrapperRectangle {
                id: image
                radius: Theme.rounding.full
                anchors.fill: parent
                anchors.centerIn: parent

                Image {
                    source: "/var/lib/AccountsService/icons/miguel"
                    anchors.fill: parent
                    sourceSize: Qt.size(Math.ceil(width * (QsWindow.window?.screen?.devicePixelRatio ?? 1)), Math.ceil(height * (QsWindow.window?.screen?.devicePixelRatio ?? 1)))
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
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
                    onClick: () => LockService.lock()
                }

                IconButtom {
                    icon: "󰂯"
                    command: ["blueberry"]
                }
                IconButtom {
                    icon: ""
                    onClick: () => userCard.powerMenuToggleRequested()
                }
            }
        }
    }

}
