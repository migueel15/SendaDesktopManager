pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

import qs.common
import qs.services
import qs.modules.bars.widgets as BarWidgets

Flickable {
    id: root

    readonly property var trayModel: SystemTray.items
    readonly property var absentPinnedIds: {
        const presentIds = root.trayModel.values.map(item => item.id);
        return TrayPins.pinnedIds.filter(id => presentIds.indexOf(id) === -1);
    }

    contentHeight: column.implicitHeight
    clip: true

    ColumnLayout {
        id: column
        width: root.width
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Iconos de la bandeja del sistema"
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(13)
        }

        Text {
            Layout.fillWidth: true
            text: "Ancla los iconos para mostrarlos junto al botón de la bandeja en todas las barras. También puedes arrastrarlos desde el desplegable."
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: presentItems.count === 0
            text: "No hay iconos en la bandeja ahora mismo"
            color: Theme.colors.overlay
            font.family: Theme.font.overlay.family
            font.pixelSize: Theme.scaled(11)
            wrapMode: Text.WordWrap
        }

        Repeater {
            id: presentItems
            model: SystemTray.items

            delegate: RowLayout {
                id: presentRow
                required property SystemTrayItem modelData
                readonly property bool pinned: TrayPins.isPinned(modelData.id)

                Layout.fillWidth: true
                spacing: 10

                BarWidgets.TrayIcon {
                    iconSize: 18
                    source: presentRow.modelData.icon
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: presentRow.modelData.tooltipTitle || presentRow.modelData.title || presentRow.modelData.id
                    color: Theme.colors.text
                    font.family: Theme.font.base.family
                    font.pixelSize: Theme.scaled(13)
                    elide: Text.ElideRight
                }

                SettingsButton {
                    label: presentRow.pinned ? "Desanclar" : "Anclar"
                    onClicked: {
                        if (presentRow.pinned)
                            TrayPins.unpin(presentRow.modelData.id);
                        else
                            TrayPins.pin(presentRow.modelData.id);
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: root.absentPinnedIds.length > 0
            text: "Anclados no abiertos ahora"
            color: Theme.colors.text
            font.family: Theme.font.base.family
            font.pixelSize: Theme.scaled(13)
        }

        Repeater {
            model: root.absentPinnedIds

            delegate: RowLayout {
                id: absentRow
                required property string modelData

                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: absentRow.modelData
                    color: Theme.colors.text
                    font.family: Theme.font.base.family
                    font.pixelSize: Theme.scaled(13)
                    elide: Text.ElideRight
                }

                SettingsButton {
                    label: "Quitar"
                    onClicked: TrayPins.unpin(absentRow.modelData)
                }
            }
        }
    }
}
