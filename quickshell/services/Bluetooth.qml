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
    readonly property list<BluetoothDevice> namedDevices: root.devices.filter(device => root.getDeviceName(device) !== "")

    function setEnabled(enabled: bool): void {
        const adapter = Bluetooth.defaultAdapter;
        if (adapter && adapter.enabled !== enabled) {
            adapter.enabled = enabled;
        }
    }

    function toggleEnabled(): void {
        root.setEnabled(!root.enabled);
    }

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

    function getDeviceName(device: BluetoothDevice): string {
        if (!device) {
            return "";
        }

        for (const candidate of [device.name, device.deviceName]) {
            const name = (candidate || "").trim();
            if (name && !/^(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(name)) {
                return name;
            }
        }
        return "";
    }

    function getDisplayName(device: BluetoothDevice): string {
        return root.getDeviceName(device) || "Dispositivo desconocido";
    }

    function getBatteryLabel(device: BluetoothDevice): string {
        if (!device || !device.connected || !device.batteryAvailable) {
            return "";
        }

        return `${Math.round(device.battery * 100)}%`;
    }
}
