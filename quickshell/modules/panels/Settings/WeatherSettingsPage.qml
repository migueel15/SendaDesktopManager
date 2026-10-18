import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services

// Weather settings: the location used by "EL TIEMPO", chosen by searching.
Flickable {
    id: root

    contentHeight: column.implicitHeight
    clip: true

    ColumnLayout {
        id: column
        width: root.width
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: `Localidad: ${SendaSettings.values.SENDA_WEATHER_LOCATION || "sin elegir"}`
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SettingsField {
                id: searchField
                Layout.fillWidth: true
                placeholder: "Busca tu localidad"
                onAccepted: SendaSettings.searchPlaces(searchField.text)
            }
            SettingsButton {
                label: "Buscar"
                enabled: !SendaSettings.busy && searchField.text.trim().length >= 2
                onClicked: SendaSettings.searchPlaces(searchField.text)
            }
        }

        Repeater {
            model: SendaSettings.places

            delegate: Rectangle {
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 34
                radius: Theme.rounding.small
                color: placeMouse.containsMouse ? Theme.colors.surfaceVariant : "transparent"

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: [modelData.name, modelData.admin, modelData.country].filter(part => part).join(", ")
                    color: Theme.colors.text
                    font.family: Theme.font.base.family
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: placeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !SendaSettings.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SendaSettings.saveLocation(modelData)
                }
            }
        }
    }
}
