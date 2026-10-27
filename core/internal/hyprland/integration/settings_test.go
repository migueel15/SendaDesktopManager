package integration

import (
	"path/filepath"
	"reflect"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestSettingsDefaultsAndExistingShortcut(t *testing.T) {
	got, err := LoadSettings(map[string]string{stt.KeyShortcut: "SUPER + d"})
	if err != nil {
		t.Fatal(err)
	}
	want := DefaultSettings()
	want.DictationShortcut = "SUPER + d"
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %#v, want %#v", got, want)
	}
}

func TestSettingsRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config")
	want := Settings{LockShortcut: "SUPER + l", DictationShortcut: "ALT + ntilde", IdleSeconds: 0, Blur: false}
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
