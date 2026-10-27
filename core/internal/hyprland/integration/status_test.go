package integration

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestIdleProcessesClassifiesConfig(t *testing.T) {
	proc := t.TempDir()
	path := "/home/user/.config/senda/hypridle.conf"
	for _, tc := range []struct{ pid, comm, cmd string }{{"101", "hypridle", "hypridle\x00-c\x00" + path + "\x00"}, {"102", "hypridle", "hypridle\x00-c\x00/home/user/other.conf\x00"}, {"103", "hypridle", "hypridle\x00"}, {"104", "other", "other\x00"}} {
		dir := filepath.Join(proc, tc.pid)
		if err := os.Mkdir(dir, 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "comm"), []byte(tc.comm+"\n"), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "cmdline"), []byte(tc.cmd), 0600); err != nil {
			t.Fatal(err)
		}
	}
	got, err := IdleProcesses(proc, os.Getuid(), path)
	if err != nil || got.Own != 1 || got.External != 2 {
		t.Fatalf("got %+v %v", got, err)
	}
}

func TestStatusReportsExternalShortcutConflict(t *testing.T) {
	tempConfig(t)
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "fake")
	run := func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		if name != "hyprctl" {
			t.Fatalf("unexpected command %s", name)
		}
		if len(args) > 0 && args[0] == "repl" {
			return []byte("true\n"), nil
		}
		return []byte(`[{"modmask":68,"key":"l","description":"Otra acción"},{"modmask":8,"key":"ntilde","description":"Senda STT toggle"}]`), nil
	}
	status := Inspect(context.Background(), DefaultSettings(), run)
	if !status.ModuleActive {
		t.Fatal("module not marked active")
	}
	joined := strings.Join(status.Warnings, "\n")
	if !strings.Contains(joined, "Otra acción") || strings.Contains(joined, "Conflicto de dictado") {
		t.Fatalf("warnings: %s", joined)
	}
}
