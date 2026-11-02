package service

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestUnitRunsShellFromExe(t *testing.T) {
	unit := Unit("/home/u/.local/bin/senda")
	for _, want := range []string{
		"ExecStart=/home/u/.local/bin/senda shell run",
		"Restart=on-failure",
		"WantedBy=default.target",
		"ExecStartPre=",
		"Type=dbus",
		"Environment=XDG_SESSION_TYPE=wayland",
		"BusName=org.kde.StatusNotifierWatcher",
		"TimeoutStartSec=30",
		"RestartSec=2",
		"StartLimitIntervalSec=0",
	} {
		if !strings.Contains(unit, want) {
			t.Errorf("unit lacks %q:\n%s", want, unit)
		}
	}
}

func TestUnitIsNotSimple(t *testing.T) {
	if unit := Unit("/home/u/.local/bin/senda"); strings.Contains(unit, "Type=simple") {
		t.Errorf("unit must not be Type=simple:\n%s", unit)
	}
}

func TestUnitQuotesPathWithSpaces(t *testing.T) {
	unit := Unit("/home/u/my bin/senda")
	if !strings.Contains(unit, `ExecStart="/home/u/my bin/senda" shell run`) {
		t.Errorf("path with spaces not quoted:\n%s", unit)
	}
}

func TestUnitPathUsesXDGConfigHome(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", "/tmp/cfg")
	if got, want := UnitPath(), filepath.Join("/tmp/cfg", "systemd", "user", "senda.service"); got != want {
		t.Errorf("UnitPath() = %q, want %q", got, want)
	}
}

func TestInUnitCgroup(t *testing.T) {
	cases := map[string]bool{
		"0::/user.slice/user-1000.slice/user@1000.service/app.slice/senda.service\n":     true,
		"0::/user.slice/user-1000.slice/user@1000.service/app.slice/t3code.service\n":    false,
		"0::/user.slice/user-1000.slice/user@1000.service/app.slice/app-kitty-1.scope\n": false,
		"0::/user.slice/user-1000.slice/user@1000.service/app.slice/my-senda.service\n":  false,
	}
	for cgroup, want := range cases {
		if got := inUnitCgroup(cgroup); got != want {
			t.Errorf("inUnitCgroup(%q) = %v, want %v", cgroup, got, want)
		}
	}
}
