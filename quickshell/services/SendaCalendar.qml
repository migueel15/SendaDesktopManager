pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reads the events of a date range through `senda calendar events`. The CLI
// holds the Google token; this service only sees JSON.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"

    // "loading", "ready", "disconnected" or "error".
    property string status: "loading"
    property string message: ""
    // Events keyed by local day, "YYYY-MM-DD". Each value is that day's events.
    property var eventsByDay: ({})

    property var lastRange: null
    property var pendingRange: null

    function pad(value) {
        return String(value).padStart(2, "0");
    }

    function isoDay(date) {
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }

    // Parses YYYY-MM-DD as a local date. new Date(text) would read it as UTC.
    function parseDay(text) {
        const [year, month, day] = text.split("-").map(Number);
        return new Date(year, month - 1, day);
    }

    function eventsOn(date) {
        return root.eventsByDay[root.isoDay(date)] ?? [];
    }

    // Loads events starting in [from, to). Calls made while a request is
    // running wait for it, so only the latest range is fetched next.
    function loadRange(from, to) {
        root.lastRange = { from: from, to: to };
        if (eventsProcess.running) {
            root.pendingRange = root.lastRange;
            return;
        }
        root.pendingRange = null;
        eventsProcess.command = [root.binaryPath, "calendar", "events", "--from", root.isoDay(from), "--to", root.isoDay(to)];
        eventsProcess.running = true;
    }

    // Reloads the last requested range, for example after the account changes.
    function refresh() {
        if (root.lastRange) {
            root.loadRange(root.lastRange.from, root.lastRange.to);
        }
    }

    function groupEvents(events) {
        const grouped = {};
        for (const event of events) {
            if (event.allDay) {
                // Google's end date is exclusive, so the event spans [start, end).
                const last = root.parseDay(event.end);
                for (let day = root.parseDay(event.start); day < last; day.setDate(day.getDate() + 1)) {
                    const key = root.isoDay(day);
                    grouped[key] = [...(grouped[key] ?? []), event];
                }
            } else {
                const key = root.isoDay(new Date(event.start));
                grouped[key] = [...(grouped[key] ?? []), event];
            }
        }
        return grouped;
    }

    Process {
        id: eventsProcess
        running: false

        stdout: StdioCollector {
            id: eventsOutput
        }

        stderr: StdioCollector {
            id: eventsErrors
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    root.eventsByDay = root.groupEvents(JSON.parse(eventsOutput.text).events);
                    root.status = "ready";
                    root.message = "";
                } catch (error) {
                    root.status = "error";
                    root.message = "La respuesta del calendario no es válida";
                }
            } else if (eventsErrors.text.includes("not connected")) {
                root.eventsByDay = ({});
                root.status = "disconnected";
                root.message = "";
            } else {
                root.status = "error";
                root.message = eventsErrors.text.trim() || "No se pudieron leer los eventos";
            }

            if (root.pendingRange) {
                const range = root.pendingRange;
                root.pendingRange = null;
                root.loadRange(range.from, range.to);
            }
        }
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
