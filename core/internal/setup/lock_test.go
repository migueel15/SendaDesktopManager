package setup

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEnsureLockIntegrationCreatesAndPreservesFiles(t *testing.T) {
	home := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", home)
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "")
	configDir := filepath.Join(home, "senda")
	executable := filepath.Join(home, "bin with space", "senda")
	original := filepath.Join(home, "hypr", "hyprland.lua")
	if err := os.MkdirAll(filepath.Dir(original), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(original, []byte("user config"), 0600); err != nil {
		t.Fatal(err)
	}
	out := &strings.Builder{}
	if err := ensureLockIntegration(configDir, executable, out); err != nil {
		t.Fatal(err)
	}
	luaPath := filepath.Join(home, "hypr", "modules", "senda.lua")
	idlePath := filepath.Join(configDir, "hypridle.conf")
	lua, err := os.ReadFile(luaPath)
	if err != nil {
		t.Fatal(err)
	}
	idle, err := os.ReadFile(idlePath)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"allow_session_lock_restore = true", "session_lock_xray = true", "session_lock_blur = true", "SUPER + CTRL + l"} {
		if !strings.Contains(string(lua), want) {
			t.Fatalf("module missing %q", want)
		}
	}
	for _, want := range []string{"'" + executable + "' lock", "inhibit_sleep = 3", "before_sleep_cmd = loginctl lock-session"} {
		if !strings.Contains(string(idle), want) {
			t.Fatalf("hypridle config missing %q", want)
		}
	}
	if err := os.WriteFile(idlePath, []byte("custom config"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := ensureLockIntegration(configDir, executable, out); err == nil {
		t.Fatal("expected refusal to overwrite user file")
	}
	data, err := os.ReadFile(idlePath)
	if err != nil || string(data) != "custom config" {
		t.Fatalf("overwritten: %q %v", data, err)
	}
	data, err = os.ReadFile(original)
	if err != nil || string(data) != "user config" {
		t.Fatalf("changed user config: %q %v", data, err)
	}
	if !strings.Contains(out.String(), `require("modules.senda")`) {
		t.Fatalf("missing instruction: %s", out)
	}
}
