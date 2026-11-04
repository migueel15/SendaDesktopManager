package integration

import (
	"fmt"
	"strconv"

	"github.com/migueel15/Zenda/core/internal/config"
	"github.com/migueel15/Zenda/core/internal/stt"
)

const (
	KeyScreenshotShortcut = "ZENDA_SCREENSHOT_SHORTCUT"
	KeyLockShortcut       = "ZENDA_LOCK_SHORTCUT"
	KeyLauncherShortcut   = "ZENDA_LAUNCHER_SHORTCUT"
	KeyEmojiShortcut      = "ZENDA_EMOJI_SHORTCUT"
	KeyIdleSeconds        = "ZENDA_IDLE_SECONDS"
	KeyBlur               = "ZENDA_LOCK_BLUR"
	KeyIdleMode           = "ZENDA_IDLE_MODE"
)

// Idle modes: Zenda runs its private hypridle, or the user keeps their own.
// An empty mode means the choice has not been made yet.
const (
	IdleModeZenda = "zenda"
	IdleModeUser  = "user"
)

// LoadSettings uses the existing dictation key so upgrades retain the shortcut.
func LoadSettings(values map[string]string) (Settings, error) {
	s := DefaultSettings()
	s.Input = LoadInputSettings(values)
	if v := values[KeyLockShortcut]; v != "" {
		s.LockShortcut = v
	}
	if v := values[stt.KeyShortcut]; v != "" {
		s.DictationShortcut = v
	}
	if v := values[KeyScreenshotShortcut]; v != "" {
		s.ScreenshotShortcut = v
	}
	launcher, launcherSet := values[KeyLauncherShortcut]
	emoji, emojiSet := values[KeyEmojiShortcut]
	if launcherSet {
		s.LauncherShortcut = launcher
	}
	if emojiSet {
		s.EmojiShortcut = emoji
	}
	dropCollidingDefaults(&s, map[string]bool{"launcher": launcherSet, "emoji": emojiSet})
	if v := values[KeyIdleSeconds]; v != "" {
		n, err := strconv.Atoi(v)
		if err != nil {
			return s, fmt.Errorf("segundos de inactividad inválidos: %w", err)
		}
		s.IdleSeconds = n
	}
	if v := values[KeyBlur]; v != "" {
		b, err := strconv.ParseBool(v)
		if err != nil {
			return s, fmt.Errorf("valor de blur inválido: %w", err)
		}
		s.Blur = b
	}
	switch v := values[KeyIdleMode]; v {
	case "", IdleModeZenda, IdleModeUser:
		s.IdleMode = v
	default:
		return s, fmt.Errorf("modo de hypridle inválido: %q", v)
	}
	var err error
	if s.Displays, err = ParseDisplays(values[KeyDisplays]); err != nil {
		return s, err
	}
	s.Startup, err = ParseStartup(values[KeyStartup])
	return s, err
}

func SaveSettings(path string, s Settings) error {
	if _, err := Render(s, "/usr/bin/zenda"); err != nil {
		return err
	}
	return config.Set(path, map[string]string{KeyScreenshotShortcut: s.ScreenshotShortcut, KeyLockShortcut: s.LockShortcut, stt.KeyShortcut: s.DictationShortcut, KeyLauncherShortcut: s.LauncherShortcut, KeyEmojiShortcut: s.EmojiShortcut, KeyIdleSeconds: strconv.Itoa(s.IdleSeconds), KeyBlur: strconv.FormatBool(s.Blur), KeyIdleMode: s.IdleMode})
}
