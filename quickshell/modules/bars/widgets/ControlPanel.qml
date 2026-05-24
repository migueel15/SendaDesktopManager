import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.common.components

Rectangle {
    id: root

    signal clicked
    property string networtIcon: Network.ethernetConnected ? "󰛳" : Network.wifiConnected ? "󰖩" : "󰲛"
    property string bluetoothIcon: Bluetooth.icon
    property string volume: Audio.icon
    property string powerIcon: "󰐥"

    property var icons: {
        // let list = [networtIcon, bluetoothIcon, volume, powerIcon];

        let list = [
            {
                "icon": networtIcon
            },
            {
                "icon": bluetoothIcon
            },
            {
                "icon": volume
            },
            {
                "icon": powerIcon
            },
        ];

        if (Battery.isLaptop) {
            list.splice(3, 0, {
                // para que se evalue en cada actualizacion y no sea una copia del valor
                "icon": Battery.icon,
                "label": Battery.label
            });
        }

        return list;
    }

    height: parent.height
    // width: 100
    implicitWidth: rectangleArea.implicitWidth
    color: "transparent"
    MouseArea {
        id: mouseArea
        hoverEnabled: true
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                root.clicked();
            } else if (event.button === Qt.RightButton) {
                Audio.muteSink();
            }
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                Audio.increaseVolume();
            } else {
                Audio.decreaseVolume();
            }
        }
    }

    Rectangle {
        id: rectangleArea
        anchors.centerIn: parent

        // width: parent.width * 0.8
        implicitWidth: rowLayout.implicitWidth + 16
        height: parent.height * 0.8

        radius: 10

        color: mouseArea.containsMouse ? Theme.colors.surfaceVariant : Theme.colors.background

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            height: parent.height
            spacing: 8
            Repeater {
                model: root.icons

                delegate: IconLabel {
                    icon: modelData.icon ?? null
                    label: modelData.label ?? null
                    font: Theme.font.base
                    color: mouseArea.containsMouse ? Theme.colors.white : Theme.colors.text
                }
            }
        }
    }
}
