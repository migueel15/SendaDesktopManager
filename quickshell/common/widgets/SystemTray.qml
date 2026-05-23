import Quickshell.Services.SystemTray
import QtQuick
import qs.common

Rectangle {
    id: root

    readonly property Repeater items: items
    property bool expanded: false

    clip: true
    visible: width > 0 && height > 0 // To avoid warnings about being visible with no size

    height: parent.height
    implicitWidth: expandButton.width + (expanded ? rectangleArea.implicitWidth : 0)
    color: "transparent"

    // Expand/collapse button
    Rectangle {
        id: expandButton
        height: parent.height * 0.8
        width: 24
        radius: 10
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        color: Theme.colors.background

        Text {
            anchors.centerIn: parent
            text: root.expanded ? "" : ""
            color: Theme.colors.text
            font: Theme.font.base
        }

        MouseArea {
            id: expandButtonMouseArea
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        id: rectangleArea
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: expandButton.right

        implicitWidth: layout.implicitWidth + 24
        height: parent.height * 0.8
        radius: 10

        opacity: expanded ? 1 : 0
        visible: opacity > 0

        color: Theme.colors.background

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        Row {
            id: layout
            anchors.centerIn: parent
            spacing: 8

            add: Transition {
                NumberAnimation {
                    properties: "scale"
                    from: 0
                    to: 1
                    duration: 300
                    easing.type: Easing.BezierSpline
                }
            }

            Repeater {
                id: items
                model: SystemTray.items
                delegate: TrayItem {}
            }
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }
}
