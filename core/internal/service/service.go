// Package service manages senda.service, the systemd user unit that runs
// Senda in the background for the whole graphical session.
package service

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Name is the systemd unit name. It covers everything Senda runs in the
// background, not only Quickshell.
const Name = "senda.service"

// sessionEnv are the variables Quickshell needs to reach the compositor.
// Hyprland exports them to the systemd user manager when it starts.
var sessionEnv = []string{"WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "XDG_CURRENT_DESKTOP"}

// UnitPath is the location of the unit in the user's systemd directory.
func UnitPath() string {
	if dir := os.Getenv("XDG_CONFIG_HOME"); filepath.IsAbs(dir) {
		return filepath.Join(dir, "systemd", "user", Name)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return filepath.Join(".config", "systemd", "user", Name)
	}
	return filepath.Join(home, ".config", "systemd", "user", Name)
}

// Unit returns the unit file content that runs exe.
//
// The unit is wanted by default.target rather than graphical-session.target,
// because plain Hyprland does not start graphical-session.target. Until the
// compositor exports its environment, ExecStartPre fails and systemd retries,
// so the shell starts as soon as Hyprland is up, without editing its config.
func Unit(exe string) string {
	return fmt.Sprintf(`[Unit]
Description=Senda desktop shell
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStartPre=/bin/sh -c '[ -n "$WAYLAND_DISPLAY" ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]'
ExecStart=%s shell run
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
`, quoteExec(exe))
}

// quoteExec quotes path for an Exec line when it contains spaces.
func quoteExec(path string) string {
	if strings.ContainsAny(path, " \t") {
		return `"` + path + `"`
	}
	return path
}

// Installed reports whether the unit file exists.
func Installed() bool {
	_, err := os.Stat(UnitPath())
	return err == nil
}

// RunningUnderSystemd reports whether this process was started by systemd as
// part of a unit, which sets INVOCATION_ID.
func RunningUnderSystemd() bool {
	return os.Getenv("INVOCATION_ID") != ""
}

// Install writes the unit for exe, enables it and (re)starts it so the
// current session gets the freshly installed files.
func Install(exe string) error {
	path := UnitPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("crear %s: %w", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(Unit(exe)), 0o644); err != nil {
		return fmt.Errorf("escribir %s: %w", path, err)
	}
	// Setup runs inside the session, so export its environment now instead
	// of waiting for the next login.
	if names := presentEnv(); len(names) > 0 {
		if err := systemctl(append([]string{"import-environment"}, names...)...); err != nil {
			return err
		}
	}
	if err := systemctl("daemon-reload"); err != nil {
		return err
	}
	if err := systemctl("enable", Name); err != nil {
		return err
	}
	return Restart()
}

// Start starts the unit.
func Start() error { return systemctl("start", Name) }

// Stop stops the unit.
func Stop() error { return systemctl("stop", Name) }

// Restart restarts the unit, starting it when it is not running.
func Restart() error { return systemctl("restart", Name) }

// RestartNoBlock queues a restart and returns at once. A process that runs
// inside the unit, such as an update launched from Quickshell, uses it,
// because the restart kills that process too.
func RestartNoBlock() error { return systemctl("--no-block", "restart", Name) }

// Remove stops and disables the unit and deletes its file. A missing unit is
// not an error.
func Remove() error {
	if !Installed() {
		return nil
	}
	if err := systemctl("disable", "--now", Name); err != nil {
		return err
	}
	if err := os.Remove(UnitPath()); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("eliminar %s: %w", UnitPath(), err)
	}
	return systemctl("daemon-reload")
}

func presentEnv() []string {
	var names []string
	for _, name := range sessionEnv {
		if os.Getenv(name) != "" {
			names = append(names, name)
		}
	}
	return names
}

func systemctl(args ...string) error {
	cmd := exec.Command("systemctl", append([]string{"--user"}, args...)...)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("systemctl --user %s: %w: %s", strings.Join(args, " "), err, strings.TrimSpace(string(out)))
	}
	return nil
}
