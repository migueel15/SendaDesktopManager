package integration

import (
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/Zenda/core/internal/config"
	"github.com/migueel15/Zenda/core/internal/stt"
)

func TestSettingsDefaultsAndExistingShortcut(t *testing.T) {
	got, err := LoadSettings(map[string]string{stt.KeyShortcut: "SUPER + d"})
	if err != nil {
		t.Fatal(err)
	}
	want := DefaultSettings()
	want.DictationShortcut = "SUPER + d"
	// The launcher default is taken, so it stays unbound instead of failing.
	want.LauncherShortcut = ""
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %#v, want %#v", got, want)
	}
}

func TestSettingsRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config")
	want := Settings{ScreenshotShortcut: "SUPER + p", LockShortcut: "SUPER + l", DictationShortcut: "ALT + ntilde", LauncherShortcut: "SUPER + space", EmojiShortcut: "SUPER + e", IdleSeconds: 0, Blur: false}
	if err := SaveSettings(path, want); err != nil {
		t.Fatal(err)
	}
	values, err := config.Load(path)
	if err != nil {
		t.Fatal(err)
	}
	got, err := LoadSettings(values)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %#v, want %#v", got, want)
	}
}

func TestSettingsRejectInvalidStoredValues(t *testing.T) {
	for _, values := range []map[string]string{{KeyIdleSeconds: "abc"}, {KeyBlur: "perhaps"}} {
		if _, err := LoadSettings(values); err == nil {
			t.Fatalf("expected error for %v", values)
		}
	}
}

func TestLauncherDefaultsYieldToExistingShortcuts(t *testing.T) {
	got, err := LoadSettings(map[string]string{KeyLockShortcut: "SUPER + period"})
	if err != nil {
		t.Fatal(err)
	}
	if got.LauncherShortcut != "SUPER + d" || got.EmojiShortcut != "" {
		t.Fatalf("launcher %q, emoji %q", got.LauncherShortcut, got.EmojiShortcut)
	}
	files, err := Render(got, "/usr/bin/zenda")
	if err != nil {
		t.Fatal(err)
	}
	for _, file := range files {
		if file.Name == "binds.lua" && (!strings.Contains(string(file.Content), "launcher toggle") || strings.Contains(string(file.Content), "--query")) {
			t.Fatalf("binds.lua:\n%s", file.Content)
		}
	}
}
