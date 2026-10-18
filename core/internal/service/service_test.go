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
	} {
		if !strings.Contains(unit, want) {
			t.Errorf("unit lacks %q:\n%s", want, unit)
		}
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
