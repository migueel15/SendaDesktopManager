package integration

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/migueel15/Zenda/core/internal/config"
	"github.com/migueel15/Zenda/core/internal/hyprland/hyprctl"
)

const (
	KeyInputLayout        = "ZENDA_INPUT_LAYOUT"
	KeyInputSensitivity   = "ZENDA_INPUT_SENSITIVITY"
	KeyInputTapToClick    = "ZENDA_INPUT_TAP_TO_CLICK"
	KeyInputNaturalScrol  = "ZENDA_INPUT_NATURAL_SCROLL"
	KeyCursorTheme        = "ZENDA_CURSOR_THEME"
	KeyCursorSize         = "ZENDA_CURSOR_SIZE"
	KeyInputAccel         = "ZENDA_INPUT_ACCEL_PROFILE"
	KeyInputFollowMouse   = "ZENDA_INPUT_FOLLOW_MOUSE"
	KeyInputDisableTyping = "ZENDA_INPUT_DISABLE_WHILE_TYPING"
	KeyInputScrollFactor  = "ZENDA_INPUT_SCROLL_FACTOR"
	KeyInputTouchpadSens  = "ZENDA_INPUT_TOUCHPAD_SENSITIVITY"
)

// Field names shared by the CLI, the JSON status and the interface.
const (
	FieldLayout        = "layout"
	FieldSensitivity   = "sensitivity"
	FieldTapToClick    = "tapToClick"
	FieldNaturalScroll = "naturalScroll"
	FieldCursorTheme   = "cursorTheme"
	FieldCursorSize    = "cursorSize"
	FieldAccelProfile  = "accelProfile"
	FieldFollowMouse   = "followMouse"
	FieldDisableTyping = "disableWhileTyping"
	FieldScrollFactor  = "scrollFactor"
	// FieldTouchpadSensitivity is empty while the touchpad follows the mouse.
	FieldTouchpadSensitivity = "touchpadSensitivity"
)

// InputSettings holds what the user chose in Zenda. An empty value means that
// Zenda has no opinion and generates nothing for that field.
type InputSettings struct {
	Layout        string
	Sensitivity   string
	TapToClick    string
	NaturalScroll string
	CursorTheme   string
	CursorSize    string
	AccelProfile  string
	FollowMouse   string
	DisableTyping string
	ScrollFactor  string
	// TouchpadSensitivity is empty while the touchpad follows the mouse.
	TouchpadSensitivity string
	// touchpads are the Hyprland names that get their own sensitivity; it is
	// filled only when the module is generated.
	touchpads []string
}

func LoadInputSettings(values map[string]string) InputSettings {
	return InputSettings{Layout: values[KeyInputLayout], Sensitivity: values[KeyInputSensitivity], TapToClick: values[KeyInputTapToClick], NaturalScroll: values[KeyInputNaturalScrol], CursorTheme: values[KeyCursorTheme], CursorSize: values[KeyCursorSize], AccelProfile: values[KeyInputAccel], FollowMouse: values[KeyInputFollowMouse], DisableTyping: values[KeyInputDisableTyping], ScrollFactor: values[KeyInputScrollFactor], TouchpadSensitivity: values[KeyInputTouchpadSens]}
}

func (s InputSettings) values() map[string]string {
	return map[string]string{KeyInputLayout: s.Layout, KeyInputSensitivity: s.Sensitivity, KeyInputTapToClick: s.TapToClick, KeyInputNaturalScrol: s.NaturalScroll, KeyCursorTheme: s.CursorTheme, KeyCursorSize: s.CursorSize, KeyInputAccel: s.AccelProfile, KeyInputFollowMouse: s.FollowMouse, KeyInputDisableTyping: s.DisableTyping, KeyInputScrollFactor: s.ScrollFactor, KeyInputTouchpadSens: s.TouchpadSensitivity}
}

// SaveInputSettings stores the fields after validating them.
func SaveInputSettings(path string, s InputSettings) error {
	if err := s.Validate(); err != nil {
		return err
	}
	return config.Set(path, s.values())
}

var layoutPattern = regexp.MustCompile(`^[a-z0-9_-]+(,[a-z0-9_-]*)*$`)

// Validate rejects what could break the generated Lua or the keyboard.
func (s InputSettings) Validate() error {
	if s.Layout != "" && !layoutPattern.MatchString(s.Layout) {
		return fmt.Errorf("distribución de teclado inválida: %q", s.Layout)
	}
	if s.Sensitivity != "" {
		v, err := strconv.ParseFloat(s.Sensitivity, 64)
		if err != nil || v < -1 || v > 1 {
			return fmt.Errorf("la velocidad del ratón debe estar entre -1 y 1")
		}
	}
	if s.TouchpadSensitivity != "" {
		v, err := strconv.ParseFloat(s.TouchpadSensitivity, 64)
		if err != nil || v < -1 || v > 1 {
			return fmt.Errorf("la velocidad del touchpad debe estar entre -1 y 1")
		}
	}
	for _, v := range []string{s.TapToClick, s.NaturalScroll, s.DisableTyping} {
		if v != "" && v != "true" && v != "false" {
			return fmt.Errorf("el valor debe ser true o false")
		}
	}
	if s.CursorSize != "" {
		if v, err := strconv.Atoi(s.CursorSize); err != nil || v < 8 || v > 128 {
			return fmt.Errorf("el tamaño del cursor debe estar entre 8 y 128")
		}
	}
	if s.AccelProfile != "" && s.AccelProfile != "adaptive" && s.AccelProfile != "flat" {
		return fmt.Errorf("la aceleración debe ser adaptive o flat")
	}
	if s.FollowMouse != "" && (len(s.FollowMouse) != 1 || s.FollowMouse < "0" || s.FollowMouse > "3") {
		return fmt.Errorf("el foco del ratón debe estar entre 0 y 3")
	}
	if s.ScrollFactor != "" {
		v, err := strconv.ParseFloat(s.ScrollFactor, 64)
		if err != nil || v < 0.1 || v > 3 {
			return fmt.Errorf("la velocidad de desplazamiento debe estar entre 0.1 y 3")
		}
	}
	if strings.ContainsAny(s.CursorTheme, "\x00\n\r/") {
		return fmt.Errorf("tema de cursor inválido")
	}
	return nil
}

// DetectInput lists the fields that the user's configuration already defines.
// Fields that nobody defines are absent, so the interface shows nothing.
func DetectInput(c UserConfig, sessionEnv map[string]string) map[string]UserSetting {
	found := map[string]UserSetting{}
	add := func(field string, s UserSetting, ok bool) {
		if ok {
			if old, seen := found[field]; !seen || old.Value == "" {
				found[field] = s
			}
		}
	}
	touchpad := []string{"input", "touchpad"}
	s, ok := c.ConfigKey([]string{"input"}, "kb_layout")
	add(FieldLayout, s, ok)
	s, ok = c.ConfigKey([]string{"input"}, "sensitivity")
	add(FieldSensitivity, s, ok)
	s, ok = c.ConfigKey(touchpad, "tap_to_click")
	add(FieldTapToClick, s, ok)
	s, ok = c.ConfigKey(touchpad, "tap-to-click")
	add(FieldTapToClick, s, ok)
	s, ok = c.ConfigKey(touchpad, "natural_scroll")
	add(FieldNaturalScroll, s, ok)
	for _, name := range []string{"XCURSOR_SIZE", "HYPRCURSOR_SIZE"} {
		s, ok = c.EnvVar(name)
		add(FieldCursorSize, s, ok)
	}
	s, ok = c.Contains(regexp.MustCompile(`hyprctl\s+setcursor|gsettings\s+set\s+org\.gnome\.desktop\.interface\s+cursor.size`))
	add(FieldCursorSize, s, ok)
	s, ok = c.ConfigKey([]string{"input"}, "accel_profile")
	add(FieldAccelProfile, s, ok)
	s, ok = c.ConfigKey([]string{"input"}, "follow_mouse")
	add(FieldFollowMouse, s, ok)
	s, ok = c.ConfigKey(touchpad, "disable_while_typing")
	add(FieldDisableTyping, s, ok)
	s, ok = c.ConfigKey(touchpad, "scroll_factor")
	add(FieldScrollFactor, s, ok)
	s, ok = c.DeviceSensitivity(touchpadNames())
	add(FieldTouchpadSensitivity, s, ok)
	for _, name := range []string{"XCURSOR_THEME", "HYPRCURSOR_THEME"} {
		s, ok = c.EnvVar(name)
		add(FieldCursorTheme, s, ok)
	}
	s, ok = c.Contains(regexp.MustCompile(`hyprctl\s+setcursor`))
	add(FieldCursorTheme, s, ok)
	s, ok = c.Contains(regexp.MustCompile(`gsettings\s+set\s+org\.gnome\.desktop\.interface\s+cursor.theme`))
	add(FieldCursorTheme, s, ok)
	for field, names := range map[string]string{FieldCursorTheme: "THEME", FieldCursorSize: "SIZE"} {
		sessionVar := regexp.MustCompile(`(?m)^\s*(?:export\s+)?(?:XCURSOR|HYPRCURSOR)_` + names + `=["']?([^"'\s]*)`)
		for file, text := range sessionEnv {
			if m := sessionVar.FindStringSubmatch(text); m != nil {
				add(field, UserSetting{Value: m[1], File: file}, true)
			}
		}
	}
	return found
}

// withoutUser drops the fields the user defines: the user always wins, and
// Zenda's module loads last, so generating them would override the user.
func (s InputSettings) withoutUser(user map[string]UserSetting) InputSettings {
	for field, target := range map[string]*string{FieldLayout: &s.Layout, FieldSensitivity: &s.Sensitivity, FieldTapToClick: &s.TapToClick, FieldNaturalScroll: &s.NaturalScroll, FieldCursorTheme: &s.CursorTheme, FieldCursorSize: &s.CursorSize, FieldAccelProfile: &s.AccelProfile, FieldFollowMouse: &s.FollowMouse, FieldDisableTyping: &s.DisableTyping, FieldScrollFactor: &s.ScrollFactor, FieldTouchpadSensitivity: &s.TouchpadSensitivity} {
		if _, ok := user[field]; ok {
			*target = ""
		}
	}
	if s.TouchpadSensitivity != "" {
		s.touchpads = touchpadNames()
	}
	return s
}

// renderInput returns the Lua for the fields that remain Zenda's.
func renderInput(s InputSettings, size int) string {
	var input, touchpad []string
	if s.Layout != "" {
		input = append(input, "kb_layout = "+strconv.Quote(s.Layout))
	}
	if s.Sensitivity != "" {
		input = append(input, "sensitivity = "+s.Sensitivity)
	}
	if s.AccelProfile != "" {
		input = append(input, "accel_profile = "+strconv.Quote(s.AccelProfile))
	}
	if s.FollowMouse != "" {
		input = append(input, "follow_mouse = "+s.FollowMouse)
	}
	if s.DisableTyping != "" {
		touchpad = append(touchpad, "disable_while_typing = "+s.DisableTyping)
	}
	if s.ScrollFactor != "" {
		touchpad = append(touchpad, "scroll_factor = "+s.ScrollFactor)
	}
	if s.TapToClick != "" {
		touchpad = append(touchpad, "tap_to_click = "+s.TapToClick)
	}
	if s.NaturalScroll != "" {
		touchpad = append(touchpad, "natural_scroll = "+s.NaturalScroll)
	}
	if len(touchpad) > 0 {
		input = append(input, "touchpad = { "+strings.Join(touchpad, ", ")+" }")
	}
	var out strings.Builder
	if len(input) > 0 {
		out.WriteString("hl.config({ input = { " + strings.Join(input, ", ") + " } })\n")
	}
	if s.TouchpadSensitivity != "" {
		for _, name := range s.touchpads {
			out.WriteString("hl.device({ name = " + strconv.Quote(name) + ", sensitivity = " + s.TouchpadSensitivity + " })\n")
		}
	}
	if s.CursorSize != "" {
		if n, err := strconv.Atoi(s.CursorSize); err == nil {
			size = n
		}
		out.WriteString(hyprctl.EnvLua("XCURSOR_SIZE", s.CursorSize) + "\n" + hyprctl.EnvLua("HYPRCURSOR_SIZE", s.CursorSize) + "\n")
		out.WriteString(hyprctl.OnStart("gsettings set "+GTKCursorSchema+" cursor-size "+s.CursorSize) + "\n")
	}
	if s.CursorTheme != "" {
		out.WriteString(hyprctl.EnvLua("XCURSOR_THEME", s.CursorTheme) + "\n" + hyprctl.EnvLua("HYPRCURSOR_THEME", s.CursorTheme) + "\n")
		out.WriteString(hyprctl.OnStart(hyprctl.SetCursorCommand(s.CursorTheme, size)) + "\n")
		out.WriteString(hyprctl.OnStart("gsettings set "+GTKCursorSchema+" "+GTKCursorKey+" '"+strings.ReplaceAll(s.CursorTheme, "'", "'\\''")+"'") + "\n")
	}
	return out.String()
}

// GTK applications read their cursor from these settings.
const (
	GTKCursorSchema = "org.gnome.desktop.interface"
	GTKCursorKey    = "cursor-theme"
)

// CursorSize is the size of the session, or Hyprland's default.
func CursorSize() int {
	if n, err := strconv.Atoi(os.Getenv("XCURSOR_SIZE")); err == nil && n > 0 {
		return n
	}
	return 24
}

// CursorThemes lists the installed themes that really contain cursors.
func CursorThemes() []string {
	home, _ := os.UserHomeDir()
	dirs := []string{filepath.Join(home, ".icons"), filepath.Join(home, ".local", "share", "icons")}
	if v := os.Getenv("XCURSOR_PATH"); v != "" {
		dirs = append(dirs, strings.Split(v, ":")...)
	}
	data := os.Getenv("XDG_DATA_DIRS")
	if data == "" {
		data = "/usr/local/share:/usr/share"
	}
	for _, d := range strings.Split(data, ":") {
		dirs = append(dirs, filepath.Join(d, "icons"))
	}
	return listCursorThemes(dirs)
}

func listCursorThemes(dirs []string) []string {
	seen := map[string]bool{}
	themes := []string{}
	for _, dir := range dirs {
		entries, _ := os.ReadDir(dir)
		for _, e := range entries {
			name := e.Name()
			// "default" only points at another theme.
			if seen[name] || name == "default" {
				continue
			}
			if info, err := os.Stat(filepath.Join(dir, name, "cursors")); err == nil && info.IsDir() {
				seen[name] = true
				themes = append(themes, name)
			}
		}
	}
	sort.Strings(themes)
	return themes
}

// SyncInputModule rewrites the module only when detection changed its content,
// so running it at login cannot cause a reload loop.
func SyncInputModule(s Settings) (bool, error) {
	exe, err := os.Executable()
	if err != nil {
		return false, err
	}
	if exe, err = filepath.EvalSymlinks(exe); err != nil {
		return false, err
	}
	before, _ := ReadGenerated()
	if err := WriteFiles(s, exe); err != nil {
		return false, err
	}
	after, err := ReadGenerated()
	return string(before) != string(after), err
}

var (
	xkbLayout     = regexp.MustCompile(`(?m)^\s*Option\s+"XkbLayout"\s+"([a-z0-9_,-]+)"`)
	consoleKeymap = regexp.MustCompile(`(?m)^\s*KEYMAP=["']?([a-z]{2})(?:[-_"'\s]|$)`)
)

// SystemLayout is the layout chosen for the system, or empty when unknown.
func SystemLayout(xorgFile, vconsoleFile string) string {
	if data, err := os.ReadFile(xorgFile); err == nil {
		if m := xkbLayout.FindSubmatch(data); m != nil {
			return string(m[1])
		}
	}
	if data, err := os.ReadFile(vconsoleFile); err == nil {
		if m := consoleKeymap.FindSubmatch(data); m != nil {
			return string(m[1])
		}
	}
	return ""
}

// WithDefaults fills what nobody chose with Zenda's defaults.
func (s InputSettings) WithDefaults() InputSettings {
	fill := func(target *string, value string) {
		if *target == "" {
			*target = value
		}
	}
	fill(&s.Layout, SystemLayout("/etc/X11/xorg.conf.d/00-keyboard.conf", "/etc/vconsole.conf"))
	fill(&s.Sensitivity, "0")
	fill(&s.AccelProfile, "flat")
	fill(&s.FollowMouse, "1")
	fill(&s.TapToClick, "true")
	fill(&s.NaturalScroll, "true")
	return s
}
