pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool ethernetConnected: false
    property bool wifiConnected: false

    Timer {
        id: ethernetCheckTimer
        interval: 10000
        running: true
        repeat: true
        onTriggered: ethernetStateProcess.running = true
    }

    Process {
        id: ethernetStateProcess
        running: true
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]

        stdout: StdioCollector {
            onStreamFinished: {
                const result = {
                    "ethernet": false,
                    "wifi": false
                };

                const connected = text.split("\n").some(line => {
                    const parts = line.split(":");
                    if (parts[1] === "ethernet" && parts[2] === "connected") {
                        result.ethernet = true;
                    }
                    if (parts[1] === "wifi" && parts[2] === "connected") {
                        result.wifi = true;
                    }
                    return result;
                });
                if (root.ethernetConnected !== result.ethernet) {
                    root.ethernetConnected = result.ethernet;
                }
                if (root.wifiConnected !== result.wifi) {
                    root.wifiConnected = result.wifi;
                }
            }
        }
    }
}
