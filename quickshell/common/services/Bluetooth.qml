pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property bool available: Bluetooth.adapters.values.length > 0
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)
    readonly property BluetoothDevice activeDevice: Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property string icon: root.enabled ? (root.connected ? "󰂱" : "󰂯") : "󰂲"
    readonly property list<BluetoothDevice> devices: Bluetooth.defaultAdapter?.devices.values ?? []

    function connectDevice(device: BluetoothDevice): void {
        if (!device || device.connected) {
            return;
        }
        device.connect();
    }

    function disconnectDevice(device: BluetoothDevice): void {
        if (!device || !device.connected) {
            return;
        }
        device.disconnect();
    }

    function getDisplayName(device: BluetoothDevice): string {
        if (!device) {
            return "Unknown device";
        }

        return device.alias || device.name || device.address || "Unknown device";
    }

    function getBatteryLabel(device: BluetoothDevice): string {
        if (!device || !device.connected || !device.batteryAvailable) {
            return "";
        }

        return `${Math.round(device.battery * 100)}%`;
    }
}
