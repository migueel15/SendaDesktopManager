package integration

import (
	"regexp"
	"strings"
	"unicode"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
)

// BindSelector finds the key binds the user defines. A computed key claims
// nothing, unlike ADR 0008's default: every bind loop would disable all keys.
var BindSelector = Selector{LuaCall: "hl.bind", ConfPattern: `^\s*bind[a-z]*\s*=\s*([^,]*,[^,]*)`}

// mediaKey is one key the media module binds. Command is a shell command, or a
// senda subcommand when Senda is true.
type mediaKey struct {
	Key, Command string
	Senda        bool
	Repeating    bool
}

const (
	sink   = "@DEFAULT_AUDIO_SINK@"
	source = "@DEFAULT_AUDIO_SOURCE@"
)

var mediaKeys = []mediaKey{
	{Key: "XF86AudioRaiseVolume", Command: "wpctl set-volume -l 1 " + sink + " 5%+", Repeating: true},
	{Key: "XF86AudioLowerVolume", Command: "wpctl set-volume " + sink + " 5%-", Repeating: true},
	{Key: "XF86AudioMute", Command: "wpctl set-mute " + sink + " toggle"},
	{Key: "XF86AudioMicMute", Command: "wpctl set-mute " + source + " toggle"},
	{Key: "XF86AudioPlay", Command: "media play-pause", Senda: true},
	{Key: "XF86AudioPause", Command: "media play-pause", Senda: true},
	{Key: "XF86AudioNext", Command: "media next", Senda: true},
	{Key: "XF86AudioPrev", Command: "media previous", Senda: true},
	{Key: "XF86MonBrightnessUp", Command: "brightness up", Senda: true, Repeating: true},
	{Key: "XF86MonBrightnessDown", Command: "brightness down", Senda: true, Repeating: true},
}

// bindSeparators split "SUPER + key" in Lua and "SUPER, key" in hyprland.conf.
var bindSeparators = regexp.MustCompile(`[,+]`)

// unmodifiedKey returns the key of a bind target with no modifiers.
func unmodifiedKey(target string) (string, bool) {
	var parts []string
	for _, part := range bindSeparators.Split(target, -1) {
		parts = append(parts, strings.FieldsFunc(part, unicode.IsSpace)...)
	}
	if len(parts) != 1 {
		return "", false
	}
	return strings.ToLower(parts[0]), true
}

func renderMediaModule(in moduleInput) (string, error) {
	defs, err := UserDefinitions(BindSelector)
	if err != nil {
		return "", err
	}
	claimed := map[string]bool{}
	for _, def := range defs {
		if key, ok := unmodifiedKey(def.Value); ok {
			claimed[key] = true
		}
	}
	var out strings.Builder
	for _, key := range mediaKeys {
		if claimed[strings.ToLower(key.Key)] {
			continue
		}
		command := key.Command
		if key.Senda {
			command = in.Command + " " + command
		}
		out.WriteString(hyprctl.BindLua(key.Key, hyprctl.DspExec(command), hyprctl.BindOptions{Description: "Senda " + key.Key, Locked: true, Repeating: key.Repeating}) + "\n")
	}
	return out.String(), nil
}
