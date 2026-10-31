pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.services

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

    readonly property int defaultWarningPercent: 20
    readonly property int warningPercent: {
        const value = Number(SendaSettings.values.SENDA_BATTERY_WARNING);
        return Number.isInteger(value) && value >= 5 && value <= 95 ? value : root.defaultWarningPercent;
    }
    // UPower reports 0 % until the device is ready, and the threshold is only
    // known once the settings are loaded.
    readonly property bool warningActive: root.isLaptop && UPower.displayDevice.ready && SendaSettings.configLoaded
    readonly property bool discharging: UPower.displayDevice.state === UPowerDeviceState.Discharging
    readonly property bool belowWarning: Math.round(root.batteryPercentage * 100) <= root.warningPercent
    // Warned already; cleared only when the charge goes back above the threshold.
    property bool warned: false

    function checkWarning() {
        if (!root.warningActive) return;
        if (!root.belowWarning) {
            root.warned = false;
        } else if (root.discharging && !root.warned) {
            root.warned = true;
            Quickshell.execDetached(["notify-send", "-a", "Senda", "-u", "critical", "-i", "battery-caution", "Batería baja", `Queda un ${root.label} de batería.`]);
        }
    }
    onWarningActiveChanged: checkWarning()
    onBelowWarningChanged: checkWarning()
    onDischargingChanged: checkWarning()
}
