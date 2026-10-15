pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool ethernetConnected: false
    property bool wifiConnected: false
    property bool wifiEnabled: false
    property string wifiSsid: ""
    property var wifiNetworks: []
    property bool wifiScanning: false
    property bool wifiBusy: false
    property string wifiNeedsPasswordFor: ""
    property string wifiError: ""
    property string pendingWifiSsid: ""
    property bool pendingWifiHasPassword: false

    function splitTerseLine(line) {
        const fields = [];
        let field = "";
        let escaped = false;

        for (let i = 0; i < line.length; i++) {
            const character = line[i];
            if (escaped) {
                field += character;
                escaped = false;
            } else if (character === "\\") {
                escaped = true;
            } else if (character === ":") {
                fields.push(field);
                field = "";
            } else {
                field += character;
            }
        }

        if (escaped) field += "\\";
        fields.push(field);
        return fields;
    }

    function refreshStatus() {
        deviceStateProcess.running = true;
        wifiRadioProcess.running = true;
        refreshWifi(false);
    }

    function refreshWifi(rescan) {
        if (!root.wifiEnabled || wifiScanProcess.running) return;
        wifiScanProcess.command = ["nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list", "--rescan", rescan ? "yes" : "no"];
        wifiScanProcess.running = true;
    }

    function updateWifiNetworks(output) {
        const bySsid = Object.create(null);
        const lines = output.split(/\r?\n/);

        for (const line of lines) {
            if (!line) continue;
            const fields = root.splitTerseLine(line);
            if (fields.length < 4 || !fields[1]) continue;

            const network = {
                ssid: fields[1],
                security: fields[2],
                signal: Number(fields[3]) || 0,
                connected: fields[0] === "*"
            };
            const previous = bySsid[network.ssid];
            if (!previous || network.signal > previous.signal || network.connected) {
                bySsid[network.ssid] = network;
            }
        }

        const networks = Object.values(bySsid).sort((a, b) => b.signal - a.signal);
        root.wifiNetworks = networks;
        const active = networks.find(network => network.connected);
        root.wifiSsid = active?.ssid ?? "";
        root.wifiConnected = !!active;
    }

    function toggleWifi() {
        if (wifiToggleProcess.running) return;
        wifiToggleProcess.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"];
        wifiToggleProcess.running = true;
    }

    function connectWifi(ssid, password) {
        if (!ssid || wifiConnectProcess.running) return;

        root.pendingWifiSsid = ssid;
        root.pendingWifiHasPassword = password !== undefined && password !== null;
        root.wifiBusy = true;
        root.wifiError = "";

        const command = ["nmcli", "device", "wifi", "connect", ssid];
        if (root.pendingWifiHasPassword) command.push("password", password);
        wifiConnectProcess.command = command;
        wifiConnectProcess.running = true;
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Process {
        id: deviceStateProcess
        running: true
        command: ["nmcli", "-t", "--escape", "yes", "-f", "DEVICE,TYPE,STATE", "device"]

        stdout: StdioCollector {
            onStreamFinished: {
                let ethernet = false;
                let wifi = false;

                for (const line of text.split(/\r?\n/)) {
                    if (!line) continue;
                    const fields = root.splitTerseLine(line);
                    if (fields[2] !== "connected") continue;
                    if (fields[1] === "ethernet") ethernet = true;
                    if (fields[1] === "wifi") wifi = true;
                }

                root.ethernetConnected = ethernet;
                if (!wifi) {
                    root.wifiConnected = false;
                    root.wifiSsid = "";
                }
            }
        }
    }

    Process {
        id: wifiRadioProcess
        running: true
        command: ["nmcli", "radio", "wifi"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";
                if (!root.wifiEnabled) {
                    root.wifiConnected = false;
                    root.wifiSsid = "";
                    root.wifiNetworks = [];
                } else {
                    root.refreshWifi(false);
                }
            }
        }
    }

    Process {
        id: wifiScanProcess
        running: false
        onRunningChanged: root.wifiScanning = running

        stdout: StdioCollector {
            onStreamFinished: root.updateWifiNetworks(text)
        }
    }

    Process {
        id: wifiToggleProcess
        running: false
        onExited: root.refreshStatus()
    }

    Process {
        id: wifiConnectProcess
        running: false
        onExited: exitCode => {
            root.wifiBusy = false;
            const hadPassword = root.pendingWifiHasPassword;
            const ssid = root.pendingWifiSsid;
            wifiConnectProcess.command = [];
            root.pendingWifiSsid = "";
            root.pendingWifiHasPassword = false;
            if (exitCode === 0) {
                root.wifiNeedsPasswordFor = "";
                root.wifiError = "";
                root.refreshStatus();
            } else if (!hadPassword) {
                root.wifiNeedsPasswordFor = ssid;
            } else {
                root.wifiError = `No se pudo conectar a ${ssid}. Revisa la contraseña.`;
            }
        }
    }
}
