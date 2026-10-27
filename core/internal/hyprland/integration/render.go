// Package integration renders Senda's Hyprland and idle configuration.
package integration

import (
	"fmt"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/version"
)

// ProbeFunction is the global Lua function the module defines. Its presence in
// the running Hyprland is how Senda knows that the module is loaded.
const ProbeFunction = "senda_module_version"

type Settings struct {
	LockShortcut      string
	DictationShortcut string
	IdleSeconds       int
	Blur              bool
	// IdleMode is IdleModeSenda, IdleModeUser or empty when undecided.
	IdleMode string
}

func DefaultSettings() Settings {
	return Settings{LockShortcut: "SUPER + CTRL + l", DictationShortcut: "ALT + ntilde", IdleSeconds: 600, Blur: true}
}

// Render produces both files from one validated set of settings. The caller
// controls persistence and activation of the generated files.
func Render(settings Settings, executable string) (lua, idle []byte, err error) {
	if !filepath.IsAbs(executable) || strings.ContainsAny(executable, "\x00\n\r") {
		return nil, nil, fmt.Errorf("ruta del ejecutable inválida")
	}
	lock, err := binds.NormalizeShortcut(settings.LockShortcut)
	if err != nil {
		return nil, nil, fmt.Errorf("atajo de bloqueo: %w", err)
	}
	dictation, err := binds.NormalizeShortcut(settings.DictationShortcut)
	if err != nil {
		return nil, nil, fmt.Errorf("atajo de dictado: %w", err)
	}
	if shortcutIdentity(lock) == shortcutIdentity(dictation) {
		return nil, nil, fmt.Errorf("los atajos de bloqueo y dictado deben ser distintos")
	}
	if settings.IdleMode != "" && settings.IdleMode != IdleModeSenda && settings.IdleMode != IdleModeUser {
		return nil, nil, fmt.Errorf("modo de hypridle inválido: %q", settings.IdleMode)
	}
	if settings.IdleSeconds < 0 || settings.IdleSeconds > 86400 {
		return nil, nil, fmt.Errorf("el tiempo de inactividad debe estar entre 0 y 86400 segundos")
	}
	command := "'" + strings.ReplaceAll(executable, "'", "'\\''") + "'"
	lua = []byte(fmt.Sprintf(`-- Generado por Senda. No modificar manualmente.
hl.config({ misc = { allow_session_lock_restore = true, session_lock_xray = %t, session_lock_blur = %t } })
hl.bind(%s, hl.dsp.exec_cmd("loginctl lock-session"), { description = "Senda lock" })
hl.bind(%s, hl.dsp.exec_cmd(%s), { submap_universal = true, description = "Senda STT toggle" })
-- Marca de detección: Senda la consulta con hyprctl para saber si el módulo
-- está cargado, esté donde esté.
function %s() return %s end
`, settings.Blur, settings.Blur, strconv.Quote(lock), strconv.Quote(dictation), strconv.Quote(command+" stt toggle"), ProbeFunction, strconv.Quote(version.Version)))
	if settings.IdleMode == IdleModeSenda {
		idleCommand := "hypridle -c '" + strings.ReplaceAll(IdlePath(), "'", "'\\''") + "'"
		lua = append(lua, fmt.Sprintf("hl.on(\"hyprland.start\", function() hl.exec_cmd(%s) end)\n", strconv.Quote(idleCommand))...)
	}
	idleText := fmt.Sprintf(`# Generado por Senda. No modificar manualmente.
general {
    lock_cmd = %s lock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({action = "on"})'
    inhibit_sleep = 3
}
`, command)
	if settings.IdleSeconds > 0 {
		idleText += fmt.Sprintf("listener {\n    timeout = %d\n    on-timeout = loginctl lock-session\n}\n", settings.IdleSeconds)
	}
	return lua, []byte(idleText), nil
}

// shortcutIdentity makes modifier ordering irrelevant when detecting collisions.
func shortcutIdentity(shortcut string) string {
	parts := strings.Split(shortcut, " + ")
	modifiers := append([]string(nil), parts[:len(parts)-1]...)
	sort.Strings(modifiers)
	return strings.Join(modifiers, "+") + "+" + strings.ToLower(parts[len(parts)-1])
}
