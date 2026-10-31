pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io

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
    readonly property bool discovering: Bluetooth.defaultAdapter?.discovering ?? false

    // Several monitors can host a control center; keep one discovery session.
    property var discoveryClients: []
    readonly property BluetoothAdapter requestedDiscoveryAdapter: root.discoveryClients.length > 0 && root.enabled ? Bluetooth.defaultAdapter : null
    property BluetoothAdapter discoveryAdapter: null
    property BluetoothDevice pairingDevice: null
    property var pairingPrompt: null
    property string pairingError: ""
    readonly property bool pairing: pairProcess.running

    function answerPairing(accept: bool, value: string): void {
        if (!root.pairingPrompt || !pairProcess.running) return;
        pairProcess.write(JSON.stringify({ id: root.pairingPrompt.id, accept: accept, value: value, cancel: !accept }) + "\n");
        root.pairingPrompt = null;
    }

    Process {
        id: pairProcess
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data);
                    root.pairingPrompt = event.kind === "paired" ? null : event;
                } catch (error) {
                    root.pairingError = "Respuesta de emparejamiento no válida";
                }
            }
        }
        stderr: StdioCollector { id: pairErrors }
        onExited: exitCode => {
            root.pairingPrompt = null;
            root.pairingDevice = null;
            if (exitCode !== 0) root.pairingError = pairErrors.text.trim() || "No se pudo emparejar el dispositivo";
        }
    }

    onRequestedDiscoveryAdapterChanged: {
        if (root.discoveryAdapter) root.discoveryAdapter.discovering = false;
        root.discoveryAdapter = root.requestedDiscoveryAdapter;
        if (root.discoveryAdapter) root.discoveryAdapter.discovering = true;
    }

    function requestDiscovery(client: QtObject, requested: bool): void {
        const clients = root.discoveryClients.filter(entry => entry !== client);
        if (requested) clients.push(client);
        root.discoveryClients = clients;
    }

    Component.onDestruction: {
        if (root.discoveryAdapter) root.discoveryAdapter.discovering = false;
    }

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
        if (!device.paired) {
            if (root.pairing) return;
            root.pairingError = "";
            root.pairingDevice = device;
            pairProcess.command = [Quickshell.env("SENDA_BIN") || "senda", "bluetooth", "pair", device.dbusPath];
            pairProcess.running = true;
        } else {
            device.connect();
        }
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
