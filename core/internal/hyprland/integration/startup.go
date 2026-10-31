package integration

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"unicode"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/service"
)

// UserStartup is the opt-in list exposed by the user's running Lua config.
// Available distinguishes an empty list from a config that exposes no list.
type UserStartup struct {
	Available bool           `json:"available"`
	Entries   []StartupEntry `json:"entries"`
}

// This expression only reads data. Never invoke startup callbacks to discover
// commands: they may launch applications or have other side effects.
const userStartupExpression = `(function()
    local entries = senda_user_startup
    if entries == nil then return "missing" end
    if type(entries) ~= "table" then return "invalid" end
    local function hex(value)
        return (value:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
    end
    local lines = {"ready"}
    for _, entry in ipairs(entries) do
        if type(entry) ~= "table" or type(entry.name) ~= "string" or type(entry.command) ~= "string" then
            return "invalid"
        end
        lines[#lines + 1] = hex(entry.name) .. ":" .. hex(entry.command)
    end
    return table.concat(lines, "\n")
end)()`

// ReadUserStartup queries an explicitly exposed table without changing config.
func ReadUserStartup(ctx context.Context, run hyprctl.Runner) (UserStartup, error) {
	result := UserStartup{Entries: []StartupEntry{}}
	text, err := hyprctl.New(run).Repl(ctx, userStartupExpression)
	if err != nil {
		return result, err
	}
	if text == "missing" {
		return result, nil
	}
	lines := strings.Split(text, "\n")
	if lines[0] != "ready" {
		return result, fmt.Errorf("la tabla senda_user_startup no tiene un formato válido")
	}
	for _, line := range lines[1:] {
		nameHex, commandHex, ok := strings.Cut(line, ":")
		name, nameErr := hex.DecodeString(nameHex)
		command, commandErr := hex.DecodeString(commandHex)
		if !ok || nameErr != nil || commandErr != nil {
			return result, fmt.Errorf("respuesta de aplicaciones de Hyprland inválida")
		}
		entry, err := NewStartupEntry(StartupApp, string(name), string(command))
		if err != nil {
			return result, err
		}
		result.Entries = append(result.Entries, entry)
	}
	result.Available = true
	return result, nil
}

// KeyStartup holds the startup entries as JSON.
const KeyStartup = "SENDA_STARTUP_APPS"

// Startup entry kinds.
const (
	StartupApp     = "app"
	StartupCommand = "command"
	StartupScript  = "script"
	StartupFile    = "file"
)

// StartupEntry is something Senda runs when Hyprland starts. Target identifies
// it: a shell command for an app or command, a path for a script or a file.
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
	if kind == StartupScript || kind == StartupFile {
		if home, err := os.UserHomeDir(); err == nil && strings.HasPrefix(target, home+"/") {
			target = "~" + strings.TrimPrefix(target, home)
		}
	}
	if name = strings.TrimSpace(name); name == "" {
		if kind == StartupCommand {
			name = target
		} else {
			name = filepath.Base(target)
		}
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
	case StartupApp, StartupCommand:
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

// startupCommand gates the whole command, including compound shell commands.
// Keep the guard out of Target so settings still show the user's command.
func (e StartupEntry) startupCommand() string {
	return "systemctl --user start " + service.Name +
		" && systemctl --user is-active --quiet " + service.Name +
		" && /bin/sh -c " + shellQuote(e.command())
}

func shellQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'" }

func shellPath(path string) string {
	if rest, ok := strings.CutPrefix(path, "~/"); ok {
		return `"$HOME"/` + shellQuote(rest)
	}
	return shellQuote(path)
}

func renderStartupEntries(entries []StartupEntry) (string, error) {
	var out strings.Builder
	for _, entry := range entries {
		if err := entry.Validate(); err != nil {
			return "", err
		}
		if entry.Enabled {
			out.WriteString(hyprctl.OnStart(entry.startupCommand()) + "\n")
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
