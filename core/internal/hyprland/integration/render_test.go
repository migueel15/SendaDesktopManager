package integration

import (
	"strings"
	"testing"
)

func TestRender(t *testing.T) {
	s := DefaultSettings()
	s.IdleSeconds = 120
	s.Blur = false
	lua, idle, err := renderParts(s, "/home/user/bin space/senda")
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"session_lock_xray = false", "session_lock_blur = false", "SUPER + CTRL + l", "ALT + ntilde", "Senda STT toggle", "Senda screenshot", "print", "screenshot"} {
		if !strings.Contains(string(lua), want) {
			t.Fatalf("missing %q: %s", want, lua)
		}
	}
	for _, want := range []string{"'/home/user/bin space/senda' lock", "timeout = 120", "inhibit_sleep = 3"} {
		if !strings.Contains(string(idle), want) {
			t.Fatalf("missing %q: %s", want, idle)
		}
	}
}
func TestInvalidSettings(t *testing.T) {
	for _, edit := range []func(*Settings){func(s *Settings) { s.ScreenshotShortcut = s.LockShortcut }, func(s *Settings) { s.ScreenshotShortcut = "" }, func(s *Settings) { s.LockShortcut = "INVALID+!" }, func(s *Settings) { s.IdleSeconds = -1 }, func(s *Settings) { s.DictationShortcut = s.LockShortcut }} {
		s := DefaultSettings()
		edit(&s)
		if _, _, err := renderParts(s, "/bin/senda"); err == nil {
			t.Fatalf("accepted %+v", s)
		}
	}
	s := DefaultSettings()
	s.IdleSeconds = 0
	_, idle, err := renderParts(s, "/bin/senda")
	if err != nil || strings.Contains(string(idle), "listener {") {
		t.Fatalf("disabled timeout: %s %v", idle, err)
	}
}

func TestEquivalentShortcutsAreRejected(t *testing.T) {
	s := DefaultSettings()
	s.LockShortcut = "SUPER + CTRL + l"
	s.DictationShortcut = "CTRL + SUPER + L"
	if _, _, err := renderParts(s, "/bin/senda"); err == nil {
		t.Fatal("accepted equivalent shortcuts")
	}
}

func TestExecutableQuotes(t *testing.T) {
	lua, idle, err := renderParts(DefaultSettings(), "/home/user/o'brien/senda")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(idle), "'\\''") || !strings.Contains(string(lua), "stt toggle") {
		t.Fatalf("bad quoting: %s %s", lua, idle)
	}
}
