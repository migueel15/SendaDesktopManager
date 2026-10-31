package integration

import (
	"fmt"
	"strconv"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

const (
	KeyScreenshotShortcut = "SENDA_SCREENSHOT_SHORTCUT"
	KeyLockShortcut       = "SENDA_LOCK_SHORTCUT"
	KeyIdleSeconds        = "SENDA_IDLE_SECONDS"
	KeyBlur               = "SENDA_LOCK_BLUR"
	KeyIdleMode           = "SENDA_IDLE_MODE"
)

// Idle modes: Senda runs its private hypridle, or the user keeps their own.
// An empty mode means the choice has not been made yet.
const (
	IdleModeSenda = "senda"
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
	case "", IdleModeSenda, IdleModeUser:
		s.IdleMode = v
	default:
		return s, fmt.Errorf("modo de hypridle inválido: %q", v)
	}
	return s, nil
}

func SaveSettings(path string, s Settings) error {
	if _, _, err := Render(s, "/usr/bin/senda"); err != nil {
		return err
	}
	return config.Set(path, map[string]string{KeyScreenshotShortcut: s.ScreenshotShortcut, KeyLockShortcut: s.LockShortcut, stt.KeyShortcut: s.DictationShortcut, KeyIdleSeconds: strconv.Itoa(s.IdleSeconds), KeyBlur: strconv.FormatBool(s.Blur), KeyIdleMode: s.IdleMode})
}
