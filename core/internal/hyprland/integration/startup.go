package integration

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"unicode"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
)

// KeyStartup holds the startup entries as JSON.
const KeyStartup = "SENDA_STARTUP_APPS"

// Startup entry kinds.
const (
	StartupApp    = "app"
	StartupScript = "script"
	StartupFile   = "file"
)

// StartupEntry is something Senda runs when Hyprland starts. Target identifies
// it: a shell command for an app, a path for a script or a file.
type StartupEntry struct {
	Kind    string `json:"kind"`
	Name    string `json:"name"`
	Target  string `json:"target"`
	Enabled bool   `json:"enabled"`
}

// NewStartupEntry returns an enabled entry. Paths under the home folder are
// stored as ~/ so that the configuration works on another computer.
func NewStartupEntry(kind, name, target string) (StartupEntry, error) {
	target = strings.TrimSpace(target)
	if kind != StartupApp {
		if home, err := os.UserHomeDir(); err == nil && strings.HasPrefix(target, home+"/") {
			target = "~" + strings.TrimPrefix(target, home)
		}
	}
	if name = strings.TrimSpace(name); name == "" {
		name = filepath.Base(target)
	}
	entry := StartupEntry{Kind: kind, Name: name, Target: target, Enabled: true}
	return entry, entry.Validate()
}

// Validate rejects what could not be written safely into the generated Lua.
func (e StartupEntry) Validate() error {
	if strings.TrimSpace(e.Target) == "" {
		return fmt.Errorf("falta qué ejecutar")
	}
	for _, r := range e.Target {
		if !unicode.IsPrint(r) {
			return fmt.Errorf("%q contiene caracteres no válidos", e.Target)
		}
	}
	switch e.Kind {
	case StartupApp:
	case StartupScript, StartupFile:
		if !strings.HasPrefix(e.Target, "/") && !strings.HasPrefix(e.Target, "~/") {
			return fmt.Errorf("%q debe ser una ruta absoluta o empezar por ~/", e.Target)
		}
	default:
		return fmt.Errorf("tipo de inicio inválido: %q", e.Kind)
	}
	return nil
}

// command is the shell command Hyprland runs for the entry.
func (e StartupEntry) command() string {
	switch e.Kind {
	case StartupScript:
		return shellPath(e.Target)
	case StartupFile:
		return "xdg-open " + shellPath(e.Target)
	}
	return e.Target
}

func shellPath(path string) string {
	quoted := func(s string) string { return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'" }
	if rest, ok := strings.CutPrefix(path, "~/"); ok {
		return `"$HOME"/` + quoted(rest)
	}
	return quoted(path)
}

func renderStartupEntries(entries []StartupEntry) (string, error) {
	var out strings.Builder
	for _, entry := range entries {
		if err := entry.Validate(); err != nil {
			return "", err
		}
		if entry.Enabled {
			out.WriteString(hyprctl.OnStart(entry.command()) + "\n")
		}
	}
	return out.String(), nil
}

// ParseStartup reads the stored entries.
func ParseStartup(value string) ([]StartupEntry, error) {
	if value == "" {
		return nil, nil
	}
	var entries []StartupEntry
	if err := json.Unmarshal([]byte(value), &entries); err != nil {
		return nil, fmt.Errorf("aplicaciones de inicio guardadas inválidas: %w", err)
	}
	for _, entry := range entries {
		if err := entry.Validate(); err != nil {
			return nil, err
		}
	}
	return entries, nil
}

// SaveStartup stores the entries in the Senda configuration.
func SaveStartup(path string, entries []StartupEntry) error {
	if len(entries) == 0 {
		return config.Set(path, map[string]string{KeyStartup: ""})
	}
	data, err := json.Marshal(entries)
	if err != nil {
		return err
	}
	return config.Set(path, map[string]string{KeyStartup: string(data)})
}
