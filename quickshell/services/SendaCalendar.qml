pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Caches calendar events by month and reads them through `senda calendar
// events`. The month before the current one and the three after it are fetched
// at startup and kept fresh. Other months are fetched when the calendar shows
// them. The CLI holds the Google token; this service only sees JSON.
Singleton {
    id: root

    readonly property string binaryPath: Quickshell.env("SENDA_BIN") || "senda"
    readonly property int cacheTtlMs: 10 * 60 * 1000
    // Months relative to the current one: the previous month, this one, and three ahead.
    readonly property var prefetchOffsets: [-1, 0, 1, 2, 3]
    readonly property int upcomingDays: 120
    readonly property var trustedLinkPrefixes: ["https://www.google.com/calendar/", "https://calendar.google.com/"]

    // "loading", "ready", "disconnected" or "error".
    property string status: "loading"
    property string message: ""
    // Events keyed by local day, "YYYY-MM-DD". Each value is that day's events.
    property var eventsByDay: ({})
    // Month key "YYYY-MM" -> time of its last successful fetch, in milliseconds.
    property var loadedAt: ({})
    // Month keys waiting to be fetched, and the one being fetched now.
    property var queue: []
    property string currentKey: ""

    function pad(value) {
        return String(value).padStart(2, "0");
    }

    function isoDay(date) {
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }

    function monthKey(date) {
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}`;
    }

    function monthStart(key) {
        const [year, month] = key.split("-").map(Number);
        return new Date(year, month - 1, 1);
    }

    // Parses YYYY-MM-DD as a local date. new Date(text) would read it as UTC.
    function parseDay(text) {
        const [year, month, day] = text.split("-").map(Number);
        return new Date(year, month - 1, day);
    }

    function eventsOn(date) {
        return root.eventsByDay[root.isoDay(date)] ?? [];
    }

    function isLoaded(date) {
        return root.loadedAt[root.monthKey(date)] !== undefined;
    }

    // Queues the months that are missing or older than the TTL. Months already
    // fresh or already queued are skipped.
    function requestMonths(dates) {
        for (const date of dates) {
            const key = root.monthKey(date);
            const lastFetch = root.loadedAt[key];
            const fresh = lastFetch !== undefined && Date.now() - lastFetch < root.cacheTtlMs;
            if (fresh || key === root.currentKey || root.queue.includes(key)) {
                continue;
            }
            root.queue = [...root.queue, key];
        }
        root.pump();
    }

    function prefetch() {
        const today = new Date();
        root.requestMonths(root.prefetchOffsets.map(offset => new Date(today.getFullYear(), today.getMonth() + offset, 1)));
    }

    // Drops the cache and fetches the prefetch window again. Used after the
    // Google account changes.
    function invalidate() {
        root.queue = [];
        root.loadedAt = ({});
        root.eventsByDay = ({});
        root.prefetch();
    }

    function pump() {
        if (eventsProcess.running || root.queue.length === 0) {
            return;
        }
        const key = root.queue[0];
        root.queue = root.queue.slice(1);
        root.currentKey = key;

        const from = root.monthStart(key);
        const to = new Date(from.getFullYear(), from.getMonth() + 1, 1);
        eventsProcess.command = [root.binaryPath, "calendar", "events", "--from", root.isoDay(from), "--to", root.isoDay(to)];
        eventsProcess.running = true;
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

    // Replaces the days of one month and keeps the rest. A multi-day event
    // fetched with one month also reaches neighbouring days, which are ignored
    // here because those days belong to another month's fetch.
    function replaceMonth(key, grouped) {
        const next = {};
        for (const day in root.eventsByDay) {
            if (!day.startsWith(key)) {
                next[day] = root.eventsByDay[day];
            }
        }
        for (const day in grouped) {
            if (day.startsWith(key)) {
                next[day] = grouped[day];
            }
        }
        root.eventsByDay = next;
    }

    // Next events from today in start order, one entry per event. It only
    // searches the cached days, so events beyond the cache are not listed.
    function upcomingEvents(limit) {
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const seen = {};
        const found = [];
        for (let offset = 0; offset < root.upcomingDays; offset++) {
            const day = new Date(today.getFullYear(), today.getMonth(), today.getDate() + offset);
            for (const event of root.eventsOn(day)) {
                const id = `${event.id}|${event.start}`;
                if (seen[id]) {
                    continue;
                }
                const start = event.allDay ? root.parseDay(event.start) : new Date(event.start);
                const upcoming = event.allDay ? start >= today : start >= now;
                if (!upcoming) {
                    continue;
                }
                seen[id] = true;
                found.push(Object.assign({}, event, { when: start.getTime() }));
            }
        }
        found.sort((first, second) => first.when - second.when);
        return found.slice(0, limit);
    }

    // Opens the event in the default browser. Only Google Calendar links are
    // opened, so a malformed link can never launch another program.
    function openEvent(event) {
        const link = event.link ?? "";
        if (root.trustedLinkPrefixes.some(prefix => link.startsWith(prefix))) {
            AppRunner.open(link);
        }
    }

    function fail(text, fallback) {
        root.queue = [];
        root.status = "error";
        root.message = text.trim() || fallback;
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
            const key = root.currentKey;
            root.currentKey = "";

            if (exitCode === 0) {
                try {
                    root.replaceMonth(key, root.groupEvents(JSON.parse(eventsOutput.text).events));
                    const loaded = Object.assign({}, root.loadedAt);
                    loaded[key] = Date.now();
                    root.loadedAt = loaded;
                    root.status = "ready";
                    root.message = "";
                } catch (error) {
                    root.fail("La respuesta del calendario no es válida", "");
                }
            } else if (eventsErrors.text.includes("not connected")) {
                root.queue = [];
                root.loadedAt = ({});
                root.eventsByDay = ({});
                root.status = "disconnected";
                root.message = "";
            } else {
                root.fail(eventsErrors.text, "No se pudieron leer los eventos");
            }

            root.pump();
        }
    }

    Timer {
        interval: root.cacheTtlMs
        running: true
        repeat: true
        onTriggered: root.prefetch()
    }

    Component.onCompleted: root.prefetch()
}
