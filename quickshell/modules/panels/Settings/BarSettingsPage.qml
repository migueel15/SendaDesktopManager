pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.common
import qs.common.components.controls
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
        spacing: Theme.spacing.md
        ZendaGroup {
            ZendaRow {
                separator: false
                label: "Bandeja del sistema"
                description: "Ancla iconos para mostrarlos en todas las barras. También puedes arrastrarlos desde el desplegable."
            }
            ZendaRow {
                visible: presentItems.count === 0
                label: "No hay iconos en la bandeja ahora mismo"
            }
            Repeater {
                id: presentItems
                model: SystemTray.items
                delegate: ZendaRow {
                    searchable: false
                    id: presentRow
                    required property SystemTrayItem modelData
                    // Removed tray items clear modelData before their delegate is destroyed.
                    label: modelData?.tooltipTitle || modelData?.title || modelData?.id || ""
                    description: modelData?.id ?? ""
                    BarWidgets.TrayIcon { iconSize: Theme.scaled(18); source: presentRow.modelData?.icon ?? "" }
                    ZendaSwitch {
                        checkedValue: !!presentRow.modelData && TrayPins.isPinned(presentRow.modelData.id)
                        Accessible.name: `Anclar ${presentRow.label}`
                        onToggledValue: value => {
                            if (value) TrayPins.pin(presentRow.modelData.id);
                            else TrayPins.unpin(presentRow.modelData.id);
                        }
                    }
                }
            }
        }
        ZendaGroup {
            visible: root.absentPinnedIds.length > 0
            ZendaRow { separator: false; label: "Anclados no abiertos ahora" }
            Repeater {
                model: root.absentPinnedIds
                delegate: ZendaRow {
                    searchable: false
                    id: absentRow
                    required property string modelData
                    label: modelData
                    ZendaButton {
                        label: "Quitar ancla"
                        onClicked: TrayPins.unpin(absentRow.modelData)
                    }
                }
            }
        }
    }
}
