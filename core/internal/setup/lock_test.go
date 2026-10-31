package setup

import (
	"bufio"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
)

// isolate points every Senda path at a temporary directory and hides the
// running session and its hypridle processes.
func isolate(t *testing.T, external int) string {
	t.Helper()
	home := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", home)
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "")
	previous := idleProcesses
	idleProcesses = func(string, int, string) (integration.Processes, error) {
		return integration.Processes{External: external}, nil
	}
	t.Cleanup(func() { idleProcesses = previous })
	return home
}

func writeFile(t *testing.T, path, data string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(data), 0600); err != nil {
		t.Fatal(err)
	}
}

func runIntegration(t *testing.T, executable, answer string) (string, error) {
	t.Helper()
	out := &strings.Builder{}
	err := ensureLockIntegration(context.Background(), executable, bufio.NewReader(strings.NewReader(answer)), out)
	return out.String(), err
}

func TestEnsureLockIntegrationCreatesAndPreservesFiles(t *testing.T) {
	home := isolate(t, 0)
	executable := filepath.Join(home, "bin with space", "senda")
	original := filepath.Join(home, "hypr", "hyprland.lua")
	writeFile(t, original, "user config")
	if _, err := runIntegration(t, executable, ""); err != nil {
		t.Fatal(err)
	}
	idlePath := filepath.Join(home, "hypr", "senda", "hypridle.conf")
	lua, err := integration.ReadGenerated()
	if err != nil {
		t.Fatal(err)
	}
	idle, err := os.ReadFile(idlePath)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"allow_session_lock_restore = true", "session_lock_blur = true", "SUPER + CTRL + l", "function " + integration.ProbeFunction + "()", "hypridle -c '", "/hypridle.conf'"} {
		if !strings.Contains(string(lua), want) {
			t.Fatalf("module missing %q:\n%s", want, lua)
		}
	}
	for _, want := range []string{"'" + executable + "' lock", "inhibit_sleep = 3", "before_sleep_cmd = loginctl lock-session"} {
		if !strings.Contains(string(idle), want) {
			t.Fatalf("hypridle config missing %q", want)
		}
	}
	data, err := os.ReadFile(original)
	if err != nil || !strings.HasPrefix(string(data), "user config\n") || !strings.HasSuffix(string(data), integration.RequireLine+" -- Senda: referencia gestionada\n") {
		t.Fatalf("require not appended: %q %v", data, err)
	}
	if _, err := runIntegration(t, executable, ""); err != nil {
		t.Fatal(err)
	}
	again, _ := os.ReadFile(original)
	if string(again) != string(data) {
		t.Fatalf("require duplicated: %q", again)
	}
	writeFile(t, idlePath, "custom config")
	if _, err := runIntegration(t, executable, ""); err == nil {
		t.Fatal("expected refusal to overwrite user file")
	}
	if data, _ := os.ReadFile(idlePath); string(data) != "custom config" {
		t.Fatalf("overwritten: %q", data)
	}
}

func TestEnsureLockIntegrationKeepsMovedRequire(t *testing.T) {
	home := isolate(t, 0)
	original := filepath.Join(home, "hypr", "hyprland.lua")
	writeFile(t, original, "  "+integration.RequireLine+"\nother()\n")
	if _, err := runIntegration(t, filepath.Join(home, "senda-bin"), ""); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(original); strings.Count(string(data), integration.RequireLine) != 1 {
		t.Fatalf("require duplicated: %q", data)
	}
}

func TestEnsureLockIntegrationAsksWhenUserHasHypridle(t *testing.T) {
	for _, tc := range []struct{ answer, mode string }{{"s\n", integration.IdleModeSenda}, {"n\n", integration.IdleModeUser}, {"", integration.IdleModeUser}} {
		home := isolate(t, 0)
		writeFile(t, filepath.Join(home, "hypr", "hyprland.lua"), "")
		writeFile(t, filepath.Join(home, "hypr", "hypridle.conf"), "general {}\n")
		out, err := runIntegration(t, filepath.Join(home, "senda-bin"), tc.answer)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(out, "¿Usar la configuración de Senda") {
			t.Fatalf("no question asked: %s", out)
		}
		s, err := integration.ReadSettings()
		if err != nil || s.IdleMode != tc.mode {
			t.Fatalf("answer %q: mode %q, want %q (%v)", tc.answer, s.IdleMode, tc.mode, err)
		}
		lua, _ := integration.ReadGenerated()
		if starts := strings.Contains(string(lua), "hypridle -c"); starts != (tc.mode == integration.IdleModeSenda) {
			t.Fatalf("mode %q: module starts hypridle = %t", tc.mode, starts)
		}
		if data, _ := os.ReadFile(filepath.Join(home, "hypr", "hypridle.conf")); string(data) != "general {}\n" {
			t.Fatalf("user hypridle changed: %q", data)
		}
		// The choice is remembered and not asked again.
		if out, _ := runIntegration(t, filepath.Join(home, "senda-bin"), ""); strings.Contains(out, "¿Usar") {
			t.Fatalf("asked twice: %s", out)
		}
	}
}

func TestEnsureLockIntegrationAsksWhenExternalHypridleRuns(t *testing.T) {
	home := isolate(t, 1)
	writeFile(t, filepath.Join(home, "hypr", "hyprland.lua"), "")
	out, err := runIntegration(t, filepath.Join(home, "senda-bin"), "")
	if err != nil || !strings.Contains(out, "¿Usar la configuración de Senda") {
		t.Fatalf("no question: %v %s", err, out)
	}
}
