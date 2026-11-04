package integration

import (
	"fmt"

	"github.com/migueel15/Zenda/core/internal/hyprland/binds"
)

// Shortcut is one key combination Zenda binds in Hyprland.
type Shortcut struct {
	// Target names the shortcut in `zenda hyprland check --for` and the UI.
	Target string
	// Label is the Spanish name used in messages.
	Label string
	// Description identifies the generated bind in `hyprctl binds`.
	Description string
	Value       string
	// Optional shortcuts may be empty, which leaves them unbound.
	Optional bool
}

// Shortcuts lists every shortcut Zenda generates, in a stable order.
func (s Settings) Shortcuts() []Shortcut {
	return []Shortcut{
		{"lock", "bloqueo", "Zenda lock", s.LockShortcut, false},
		{"dictation", "dictado", binds.DictationDescription, s.DictationShortcut, false},
		{"screenshot", "captura", "Zenda screenshot", s.ScreenshotShortcut, false},
		{"launcher", "launcher", "Zenda launcher", s.LauncherShortcut, true},
		{"emoji", "emojis", "Zenda emoji", s.EmojiShortcut, true},
	}
}

// IsShortcutTarget reports whether target names a generated shortcut.
func IsShortcutTarget(target string) bool {
	for _, shortcut := range DefaultSettings().Shortcuts() {
		if shortcut.Target == target {
			return true
		}
	}
	return false
}

// IsGeneratedBind reports whether description belongs to a bind Zenda generates.
func IsGeneratedBind(description string) bool {
	for _, shortcut := range DefaultSettings().Shortcuts() {
		if shortcut.Description == description {
			return true
		}
	}
	return false
}

// normalizedShortcuts validates every shortcut and rejects duplicates.
func normalizedShortcuts(s Settings) (map[string]string, error) {
	result := map[string]string{}
	seen := map[string]string{}
	for _, shortcut := range s.Shortcuts() {
		if shortcut.Optional && shortcut.Value == "" {
			continue
		}
		normalized, err := binds.NormalizeShortcut(shortcut.Value)
		if err != nil {
			return nil, fmt.Errorf("atajo de %s: %w", shortcut.Label, err)
		}
		identity := shortcutIdentity(normalized)
		if other, ok := seen[identity]; ok {
			return nil, fmt.Errorf("los atajos de %s y %s deben ser distintos", other, shortcut.Label)
		}
		seen[identity] = shortcut.Label
		result[shortcut.Target] = normalized
	}
	return result, nil
}

// dropCollidingDefaults unbinds optional shortcuts the user never set whose
// default is already taken, so upgrading never breaks an existing setup.
func dropCollidingDefaults(s *Settings, explicit map[string]bool) {
	taken := map[string]bool{}
	for _, shortcut := range s.Shortcuts() {
		if shortcut.Optional && !explicit[shortcut.Target] {
			continue
		}
		if normalized, err := binds.NormalizeShortcut(shortcut.Value); err == nil {
			taken[shortcutIdentity(normalized)] = true
		}
	}
	for _, field := range []struct {
		target string
		value  *string
	}{{"launcher", &s.LauncherShortcut}, {"emoji", &s.EmojiShortcut}} {
		if explicit[field.target] || *field.value == "" {
			continue
		}
		normalized, err := binds.NormalizeShortcut(*field.value)
		if err != nil || taken[shortcutIdentity(normalized)] {
			*field.value = ""
			continue
		}
		taken[shortcutIdentity(normalized)] = true
	}
}
