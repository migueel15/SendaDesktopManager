package stt

import (
	"path/filepath"
	"regexp"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
)

const (
	KeyModel        = "SENDA_STT_MODEL"
	KeyLanguage     = "SENDA_STT_LANGUAGE"
	KeyPasteMode    = "SENDA_STT_PASTE_MODE"
	KeyShortcut     = "SENDA_STT_SHORTCUT"
	KeyTerminals    = "SENDA_STT_TERMINALS"
	DefaultModelID  = "nemotron-3.5-streaming-0.6b-int8"
	DefaultLanguage = "es"
	DefaultShortcut = "ALT + ntilde"
)

type PasteMode string

const (
	PasteDirect    PasteMode = "paste"
	PasteClipboard PasteMode = "clipboard"
)

var DefaultTerminals = []string{"kitty", "foot", "Alacritty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty"}

type Settings struct {
	ModelID, Language string
	PasteMode         PasteMode
	Shortcut          string
	Terminals         []string
}

var modelPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9._-]*$`)
var languagePattern = regexp.MustCompile(`^(auto|[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*)$`)
var shortcutPattern = regexp.MustCompile(`(?i)^(?:(?:SUPER|ALT|CTRL|CONTROL|SHIFT|MOD[1-5])\s*\+\s*)*[a-z0-9_ñ]+$`)
var terminalPattern = regexp.MustCompile(`^[a-zA-Z0-9_.-]+$`)

// LoadSettings substitutes defaults for empty or invalid values. Terminal
// classes are comma-separated; returned slices never alias DefaultTerminals.
func LoadSettings(values map[string]string) Settings {
	s := Settings{ModelID: DefaultModelID, Language: DefaultLanguage, PasteMode: PasteDirect,
		Shortcut: DefaultShortcut, Terminals: append([]string(nil), DefaultTerminals...)}
	if v := strings.TrimSpace(values[KeyModel]); modelPattern.MatchString(v) {
		s.ModelID = v
	}
	if v := strings.TrimSpace(values[KeyLanguage]); languagePattern.MatchString(v) {
		s.Language = v
	}
	if v := PasteMode(strings.TrimSpace(values[KeyPasteMode])); v == PasteDirect || v == PasteClipboard {
		s.PasteMode = v
	}
	if v := strings.TrimSpace(values[KeyShortcut]); shortcutPattern.MatchString(v) {
		s.Shortcut = v
	}
	var terminals []string
	for _, v := range strings.Split(values[KeyTerminals], ",") {
		v = strings.TrimSpace(v)
		if v == "" {
			continue
		}
		if !terminalPattern.MatchString(v) {
			return s
		}
		terminals = append(terminals, v)
	}
	if len(terminals) > 0 {
		s.Terminals = terminals
	}
	return s
}

func Dir() string        { return filepath.Join(paths.DataDir(), "stt") }
func ModelsDir() string  { return filepath.Join(Dir(), "models") }
func RuntimeDir() string { return filepath.Join(Dir(), "venv") }
