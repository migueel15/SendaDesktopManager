package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

func integrationTestEnv(t *testing.T) {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("HOME", dir)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(dir, "config"))
	t.Setenv("XDG_RUNTIME_DIR", filepath.Join(dir, "runtime"))
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "fake")
	t.Setenv("WAYLAND_DISPLAY", "fake")
	bin := filepath.Join(dir, "bin")
	if err := os.MkdirAll(bin, 0700); err != nil {
		t.Fatal(err)
	}
	script := `#!/bin/sh
case "$1" in
repl) printf 'dev\t@/fake/senda.lua\n';;
reload) echo ok;;
configerrors) :;;
-j) echo '[{"modmask":64,"key":"d","submap":"","description":"Lanzador"},{"modmask":68,"key":"l","submap":"","description":"Senda lock"}]';;
dispatch) echo "$2" >> "$HOME/dispatched"; echo ok;;
eval) echo eval >> "$HOME/dispatched"; echo ok;;
esac
`
	if err := os.WriteFile(filepath.Join(bin, "hyprctl"), []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	oldExe, oldIdle, oldStop := hyprlandExecutable, applyIdle, stopExternalIdle
	stopExternalIdle = func() string { t.Fatal("stopped hypridle without being asked"); return "" }
	hyprlandExecutable = func() (string, error) { return "/usr/bin/senda", nil }
	applyIdle = func() string { return "" }
	t.Cleanup(func() { hyprlandExecutable = oldExe; applyIdle = oldIdle; stopExternalIdle = oldStop })
}
func runCommand(t *testing.T, cmd *cobra.Command, args ...string) (string, error) {
	t.Helper()
	var out bytes.Buffer
	cmd.SetOut(&out)
	cmd.SetErr(&out)
	cmd.SetArgs(args)
	err := cmd.Execute()
	return out.String(), err
}
func TestHyprlandCLIAndDictationShareSettings(t *testing.T) {
	integrationTestEnv(t)
	out, err := runCommand(t, hyprlandCmd(), "set", "--lock-shortcut", "SUPER + x", "--dictation-shortcut", "ALT + d", "--idle-seconds", "0", "--blur", "false", "--json")
	if err != nil {
		t.Fatalf("set: %v %s", err, out)
	}
	var obj map[string]any
	if err = json.Unmarshal([]byte(out), &obj); err != nil {
		t.Fatal(err)
	}
	want := []string{"screenshotShortcut", "defaultScreenshotShortcut", "lockShortcut", "dictationShortcut", "idleSeconds", "blur", "modulePath", "moduleActive", "idleConfigPath", "idleMode", "defaultLockShortcut", "defaultDictationShortcut", "warnings"}
	if len(obj) != len(want) {
		t.Fatalf("JSON keys %v", obj)
	}
	for _, key := range want {
		if _, ok := obj[key]; !ok {
			t.Fatalf("missing %s", key)
		}
	}
	if obj["lockShortcut"] != "SUPER + x" || obj["dictationShortcut"] != "ALT + d" || obj["idleSeconds"] != float64(0) || obj["blur"] != false || obj["moduleActive"] != true {
		t.Fatalf("status %v", obj)
	}
	idle, err := os.ReadFile(integration.IdlePath())
	if err != nil || strings.Contains(string(idle), "listener {") {
		t.Fatalf("idle %q %v", idle, err)
	}
	out, err = runCommand(t, sttShortcutCmd(), "set", "CTRL + d", "--json")
	if err != nil {
		t.Fatalf("stt set: %v %s", err, out)
	}
	var old map[string]any
	if err = json.Unmarshal([]byte(out), &old); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"shortcut", "path", "exists", "loaded", "requireLine", "conflicts"} {
		if _, ok := old[key]; !ok {
			t.Fatalf("missing legacy key %s", key)
		}
	}
	if old["shortcut"] != "CTRL + d" || old["path"] != integration.ModulePath() {
		t.Fatalf("old status %v", old)
	}
	out, err = runCommand(t, hyprlandCmd(), "show", "--json")
	if err != nil {
		t.Fatal(err)
	}
	if err = json.Unmarshal([]byte(out), &obj); err != nil || obj["dictationShortcut"] != "CTRL + d" {
		t.Fatalf("show %s %v", out, err)
	}
}
func TestHyprlandInvalidSettingsNeverWrite(t *testing.T) {
	integrationTestEnv(t)
	if _, err := runCommand(t, hyprlandCmd(), "set", "--json"); err != nil {
		t.Fatal(err)
	}
	pathsToCheck := []string{paths.ConfigFile(), integration.ModulePath(), integration.IdlePath()}
	before := make([][]byte, len(pathsToCheck))
	for i, p := range pathsToCheck {
		before[i], _ = os.ReadFile(p)
	}
	for _, args := range [][]string{{"set", "--lock-shortcut", "!"}, {"set", "--idle-seconds", "-1"}, {"set", "--blur", "yes"}, {"set", "--dictation-shortcut", "SUPER + CTRL + l"}} {
		if out, err := runCommand(t, hyprlandCmd(), args...); err == nil {
			t.Fatalf("accepted %v: %s", args, out)
		}
		for i, p := range pathsToCheck {
			now, err := os.ReadFile(p)
			if err != nil || !reflect.DeepEqual(now, before[i]) {
				t.Fatalf("changed %s on %v", p, args)
			}
		}
	}
}

func TestHyprlandIdleModeChoice(t *testing.T) {
	integrationTestEnv(t)
	stopped, applied := 0, 0
	stopExternalIdle = func() string { stopped++; return "" }
	applyIdle = func() string { applied++; return "" }
	if out, err := runCommand(t, hyprlandCmd(), "set", "--idle-seconds", "60"); err != nil {
		t.Fatalf("%v %s", err, out)
	}
	if stopped != 0 || applied != 0 {
		t.Fatalf("hypridle touched without a choice: stop %d apply %d", stopped, applied)
	}
	if out, err := runCommand(t, hyprlandCmd(), "set", "--idle-mode", "senda", "--json"); err != nil || !strings.Contains(out, `"idleMode":"senda"`) {
		t.Fatalf("%v %s", err, out)
	}
	if stopped != 1 || applied != 1 {
		t.Fatalf("stop %d apply %d", stopped, applied)
	}
	if out, err := runCommand(t, hyprlandCmd(), "set", "--idle-mode", "other"); err == nil {
		t.Fatalf("accepted invalid mode: %s", out)
	}
}

func TestHyprlandCheckReportsConflicts(t *testing.T) {
	integrationTestEnv(t)
	for _, tc := range []struct {
		target, shortcut, want string
		conflicts              int
	}{
		{"screenshot", "Print", "print", 0},
		{"screenshot", "ALT + ntilde", "ALT + ntilde", 1},
		{"lock", "Print", "print", 1},
		{"lock", "super + d", "SUPER + d", 1},
		{"lock", "SUPER + CTRL + l", "SUPER + CTRL + l", 0},
		{"dictation", "CTRL + SUPER + L", "CTRL + SUPER + l", 1},
		{"lock", "ALT + ntilde", "ALT + ntilde", 1},
		{"dictation", "SUPER + F5", "SUPER + f5", 0},
	} {
		out, err := runCommand(t, hyprlandCmd(), "check", "--for", tc.target, "--shortcut", tc.shortcut)
		if err != nil {
			t.Fatalf("%v %s", err, out)
		}
		var got shortcutCheck
		if err := json.Unmarshal([]byte(out), &got); err != nil {
			t.Fatal(err)
		}
		if got.Shortcut != tc.want || len(got.Conflicts) != tc.conflicts {
			t.Fatalf("%s %q: %+v", tc.target, tc.shortcut, got)
		}
	}
	if _, err := runCommand(t, hyprlandCmd(), "check", "--for", "lock", "--shortcut", "SUPER + !"); err == nil {
		t.Fatal("accepted an invalid key")
	}
}

func TestHyprlandCaptureSwitchesSubmap(t *testing.T) {
	integrationTestEnv(t)
	for _, step := range []string{"start", "stop"} {
		if out, err := runCommand(t, hyprlandCmd(), "capture", step); err != nil {
			t.Fatalf("%s: %v %s", step, err, out)
		}
	}
	data, _ := os.ReadFile(filepath.Join(os.Getenv("HOME"), "dispatched"))
	if string(data) != "eval\nhl.dsp.submap(\"senda_capture\")\nhl.dsp.submap(\"reset\")\n" {
		t.Fatalf("dispatched: %q", data)
	}
}
