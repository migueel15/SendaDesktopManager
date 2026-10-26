pragma ComponentBehavior: Bound

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

        SettingsGroup {

            SettingsRow {
                separator: false
                label: "Localidad"
                description: SendaSettings.values.SENDA_WEATHER_LOCATION
                    || (SendaSettings.defaultWeatherLocation ? `${SendaSettings.defaultWeatherLocation} (según tu zona horaria)` : "Sin elegir")
                SettingsField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.preferredWidth: 140
                    placeholder: "Busca tu localidad"
                    enabled: !SendaSettings.busy
                    onAccepted: if (!SendaSettings.busy) SendaSettings.searchPlaces(text)
                }
                SettingsButton {
                    label: "Buscar"
                    enabled: !SendaSettings.busy && searchField.text.trim().length >= 2
                    onClicked: SendaSettings.searchPlaces(searchField.text)
                }
            }
            Repeater {
                model: SendaSettings.places
                delegate: SettingsRow {
                    id: placeRow
                    required property var modelData
                    label: modelData.name
                    description: [modelData.admin, modelData.country].filter(part => part).join(", ")
                    SettingsButton {
                        label: "Elegir"
                        enabled: !SendaSettings.busy
                        onClicked: SendaSettings.saveLocation(placeRow.modelData)
                    }
                }
            }
        }
    }
}
