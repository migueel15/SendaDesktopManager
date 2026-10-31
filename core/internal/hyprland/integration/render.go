// Package integration renders Senda's Hyprland and idle configuration.
package integration

import (
	"fmt"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
)

// ProbeFunction is the global Lua function the module defines. Its presence in
// the running Hyprland is how Senda knows that the module is loaded.
const ProbeFunction = "senda_module_version"

// CaptureSubmap has no binds besides Escape, so Hyprland lets every other key
// combination reach Senda while a shortcut is being recorded.
const CaptureSubmap = "senda_capture"

// SettingsWindowTitle is the title of the settings window.
const SettingsWindowTitle = "Ajustes de Senda"

// SettingsWindowRule opens the settings window floating and centred on the
// focused monitor. The module carries it and `senda settings` registers it
// again before opening, so it applies without regenerating the module.
func SettingsWindowRule() hyprctl.WindowRule {
	return hyprctl.WindowRule{Name: "Senda settings", MatchTitle: "^" + regexp.QuoteMeta(SettingsWindowTitle) + "$", Float: true, Center: true}
}

type Settings struct {
	ScreenshotShortcut string
	LockShortcut       string
	DictationShortcut  string
	IdleSeconds        int
	Blur               bool
	// IdleMode is IdleModeSenda, IdleModeUser or empty when undecided.
	IdleMode string
	// Displays are the monitor rules to generate, without those the user owns.
	Displays []DisplayRule
	// Input is what Senda generates, without the fields the user defines.
	Input InputSettings
}

func DefaultSettings() Settings {
	return Settings{ScreenshotShortcut: "Print", LockShortcut: "SUPER + CTRL + l", DictationShortcut: "ALT + ntilde", IdleSeconds: 600, Blur: true}
}

// Render produces every generated file from one validated set of settings. The
// caller controls persistence and activation of the generated files.
func Render(settings Settings, executable string) (Generated, error) {
	if !filepath.IsAbs(executable) || strings.ContainsAny(executable, "\x00\n\r") {
		return nil, fmt.Errorf("ruta del ejecutable inválida")
	}
	lock, err := binds.NormalizeShortcut(settings.LockShortcut)
	if err != nil {
		return nil, fmt.Errorf("atajo de bloqueo: %w", err)
	}
	dictation, err := binds.NormalizeShortcut(settings.DictationShortcut)
	if err != nil {
		return nil, fmt.Errorf("atajo de dictado: %w", err)
	}
	screenshot, err := binds.NormalizeShortcut(settings.ScreenshotShortcut)
	if err != nil {
		return nil, fmt.Errorf("atajo de captura: %w", err)
	}
	if shortcutIdentity(screenshot) == shortcutIdentity(lock) || shortcutIdentity(screenshot) == shortcutIdentity(dictation) {
		return nil, fmt.Errorf("el atajo de captura debe ser distinto de bloqueo y dictado")
	}
	if shortcutIdentity(lock) == shortcutIdentity(dictation) {
		return nil, fmt.Errorf("los atajos de bloqueo y dictado deben ser distintos")
	}
	if settings.IdleMode != "" && settings.IdleMode != IdleModeSenda && settings.IdleMode != IdleModeUser {
		return nil, fmt.Errorf("modo de hypridle inválido: %q", settings.IdleMode)
	}
	if settings.IdleSeconds < 0 || settings.IdleSeconds > 86400 {
		return nil, fmt.Errorf("el tiempo de inactividad debe estar entre 0 y 86400 segundos")
	}
	command := "'" + strings.ReplaceAll(executable, "'", "'\\''") + "'"
	files := Generated{{initFile, []byte(generatedInit())}}
	input := moduleInput{Settings: settings, Lock: lock, Dictation: dictation, Screenshot: screenshot, Command: command}
	for _, module := range generatedModules {
		text, err := module.Render(input)
		if err != nil {
			return nil, err
		}
		files = append(files, GeneratedFile{module.Name + ".lua", []byte(fileHeader + text)})
	}
	idleText := fmt.Sprintf(`# Generado por Senda. No modificar manualmente.
general {
    lock_cmd = %s lock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = %s
    inhibit_sleep = 3
}
`, command, hyprctl.DispatchCommand(hyprctl.DspDpmsOn()))
	if settings.IdleSeconds > 0 {
		idleText += fmt.Sprintf("listener {\n    timeout = %d\n    on-timeout = loginctl lock-session\n}\n", settings.IdleSeconds)
	}
	return append(files, GeneratedFile{idleFile, []byte(idleText)}, GeneratedFile{".gitignore", []byte(idleHeader + " Se regenera; no se versiona.\n*\n")}), nil
}

// shortcutIdentity makes modifier ordering irrelevant when detecting collisions.
func shortcutIdentity(shortcut string) string {
	parts := strings.Split(shortcut, " + ")
	modifiers := append([]string(nil), parts[:len(parts)-1]...)
	sort.Strings(modifiers)
	return strings.Join(modifiers, "+") + "+" + strings.ToLower(parts[len(parts)-1])
}
