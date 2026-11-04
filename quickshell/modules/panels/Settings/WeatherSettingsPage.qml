pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services

// Weather settings: the location used by "EL TIEMPO", chosen by searching.
Flickable {
    id: root
    readonly property bool retainWhenHidden: searchField.text !== ""

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
                description: ZendaSettings.values.ZENDA_WEATHER_LOCATION
                    || (ZendaSettings.defaultWeatherLocation ? `${ZendaSettings.defaultWeatherLocation} (según tu zona horaria)` : "Sin elegir")
                SettingsField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.preferredWidth: 140
                    placeholder: "Busca tu localidad"
                    enabled: !ZendaSettings.busy
                    onAccepted: if (!ZendaSettings.busy) ZendaSettings.searchPlaces(text)
                }
                SettingsButton {
                    label: "Buscar"
                    enabled: !ZendaSettings.busy && searchField.text.trim().length >= 2
                    onClicked: ZendaSettings.searchPlaces(searchField.text)
                }
            }
            Repeater {
                model: ZendaSettings.places
                delegate: SettingsRow {
                    searchable: false
                    id: placeRow
                    required property var modelData
                    label: modelData.name
                    description: [modelData.admin, modelData.country].filter(part => part).join(", ")
                    SettingsButton {
                        label: "Elegir"
                        enabled: !ZendaSettings.busy
                        onClicked: ZendaSettings.saveLocation(placeRow.modelData)
                    }
                }
            }
        }
    }
}
