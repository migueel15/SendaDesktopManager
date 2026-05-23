pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property bool isLaptop: UPower.displayDevice.isLaptopBattery ?? false
    readonly property real batteryPercentage: UPower.displayDevice.percentage ?? 0
	readonly property bool isCharging: UPower.displayDevice.state === UPowerDeviceState.Charging
    property string icon: {
        let icon = "";
        const charginIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
        const batteryIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹",];
        const idx = Math.max(1, Math.min(10, Math.ceil(root.batteryPercentage * 10))) - 1;

        if (root.isLaptop) {
            if (root.isCharging) {
                icon = charginIcons[idx];
            } else {
                icon = batteryIcons[idx];
            }
        }
        return icon;
    }
    property string label: `${(root.batteryPercentage * 100).toFixed(0)}%`
}
