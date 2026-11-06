pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.services
import qs.common
import qs.common.components.controls

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

        ZendaGroup {

            ZendaRow {
                separator: false
                label: "Localidad"
                description: ZendaSettings.values.ZENDA_WEATHER_LOCATION
                    || (ZendaSettings.defaultWeatherLocation ? `${ZendaSettings.defaultWeatherLocation} (según tu zona horaria)` : "Sin elegir")
                ZendaField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.preferredWidth: 140
                    placeholder: "Busca tu localidad"
                    enabled: !ZendaSettings.searching
                    onAccepted: if (!ZendaSettings.searching) ZendaSettings.searchPlaces(text)
                }
                ZendaButton {
                    label: "Buscar"
                    enabled: !ZendaSettings.searching && searchField.text.trim().length >= 2
                    onClicked: ZendaSettings.searchPlaces(searchField.text)
                }
            }
            Repeater {
                model: ZendaSettings.places
                delegate: ZendaRow {
                    searchable: false
                    id: placeRow
                    required property var modelData
                    label: modelData.name
                    description: [modelData.admin, modelData.country].filter(part => part).join(", ")
                    ZendaButton {
                        label: "Elegir"
                        enabled: ZendaSettings.configLoaded
                        onClicked: ZendaSettings.saveLocation(placeRow.modelData)
                    }
                }
            }
        }
    }
}
