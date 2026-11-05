package stt

import (
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/migueel15/Zenda/core/internal/paths"
)

const (
	KeyAudioDucking = "ZENDA_STT_AUDIO_DUCKING"
	KeyAudioVolume  = "ZENDA_STT_AUDIO_VOLUME"
	KeyPreload      = "ZENDA_STT_PRELOAD"
	KeyLiveText     = "ZENDA_STT_LIVE_TEXT"
	KeyModel        = "ZENDA_STT_MODEL"
	KeyLanguage     = "ZENDA_STT_LANGUAGE"
	KeyPasteMode    = "ZENDA_STT_PASTE_MODE"
	KeyShortcut     = "ZENDA_STT_SHORTCUT"
	KeyTerminals    = "ZENDA_STT_TERMINALS"
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
	Preload           bool
	// LiveText shows the transcript in the dock while dictating; only the shell reads it.
	LiveText     bool
	AudioDucking bool
	AudioVolume  int
}

var modelPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9._-]*$`)
var languagePattern = regexp.MustCompile(`^(auto|[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*)$`)
var shortcutPattern = regexp.MustCompile(`(?i)^(?:(?:SUPER|ALT|CTRL|CONTROL|SHIFT|MOD[1-5])\s*\+\s*)*[a-z0-9_ñ]+$`)
var terminalPattern = regexp.MustCompile(`^[a-zA-Z0-9_.-]+$`)

// LoadSettings substitutes defaults for empty or invalid values. Terminal
// classes are comma-separated; returned slices never alias DefaultTerminals.
func LoadSettings(values map[string]string) Settings {
	s := Settings{AudioDucking: true, LiveText: true, AudioVolume: 10, ModelID: DefaultModelID, Language: DefaultLanguage, PasteMode: PasteDirect,
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
	s.AudioDucking = strings.TrimSpace(values[KeyAudioDucking]) != "false"
	if v, err := strconv.Atoi(strings.TrimSpace(values[KeyAudioVolume])); err == nil && v >= 0 && v <= 100 {
		s.AudioVolume = v
	}
	s.Preload = strings.TrimSpace(values[KeyPreload]) == "true"
	s.LiveText = strings.TrimSpace(values[KeyLiveText]) != "false"
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
