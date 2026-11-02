pragma Singleton

import Quickshell

// Starts user applications in their own systemd scope. Anything left in the
// senda.service cgroup dies whenever that unit restarts, so applications must
// never be started directly from the shell.
Singleton {
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"

    function run(command, workingDirectory) {
        const argv = Array.from(command);
        const inDirectory = workingDirectory ? ["sh", "-c", 'cd "$0" && exec "$@"', workingDirectory] : [];
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", "--"].concat(inDirectory, argv));
    }
    function runEntry(entry) {
        const argv = Array.from(entry.command);
        run(entry.runInTerminal ? [terminal, "-e"].concat(argv) : argv, entry.workingDirectory);
    }
    function open(url) {
        run(["xdg-open", String(url)]);
    }
}
