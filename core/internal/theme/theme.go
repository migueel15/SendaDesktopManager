// Package theme defines the shared on-disk theme contract.
package theme

import (
	"encoding/json"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"os"
	"path/filepath"
	"regexp"
	"sort"
)

const DefaultTheme = "zenda-ice"

// ColorKeys is the ordered palette consumed by the shell.
var ColorKeys = []string{"base", "background", "surface", "border", "surfaceVariant", "surfaceRaised", "surfaceRaisedBorder", "overlay", "textMuted", "white", "primary", "secondary", "accent", "accentDeep", "selection", "focus", "success", "warning", "error", "info", "text"}

var namePattern = regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`)
var colorPattern = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

type Theme struct {
	Name      string            `json:"name"`
	Wallpaper string            `json:"wallpaper"`
	Colors    map[string]string `json:"colors"`
}

type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

func (e *ValidationError) Error() string  { return e.Field + ": " + e.Message }
func invalid(field, message string) error { return &ValidationError{field, message} }

// Load parses the exact JSON contract and validates the wallpaper relative to path.
func Load(path string) (Theme, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Theme{}, invalid("json", err.Error())
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil || fields == nil {
		return Theme{}, invalid("json", "invalid JSON object")
	}
	for _, key := range []string{"name", "wallpaper", "colors"} {
		if _, ok := fields[key]; !ok {
			return Theme{}, invalid(key, "required field")
		}
	}
	keys := make([]string, 0, len(fields))
	for key := range fields {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		if key != "name" && key != "wallpaper" && key != "colors" {
			return Theme{}, invalid("json", "unknown field: "+key)
		}
	}
	var t Theme
	if err := json.Unmarshal(fields["name"], &t.Name); err != nil {
		return t, invalid("name", "expected string")
	}
	if err := json.Unmarshal(fields["wallpaper"], &t.Wallpaper); err != nil {
		return t, invalid("wallpaper", "expected string")
	}
	var colors map[string]json.RawMessage
	if err := json.Unmarshal(fields["colors"], &colors); err != nil || colors == nil {
		return t, invalid("colors", "expected object")
	}
	t.Colors = make(map[string]string, len(colors))
	for key, raw := range colors {
		var value string
		if err := json.Unmarshal(raw, &value); err != nil {
			return t, invalid("colors."+key, "expected hex color")
		}
		t.Colors[key] = value
	}
	return t, Validate(t, filepath.Dir(path), "")
}

// Validate accepts an explicit expected name so temporary save directories work.
// An empty expectedName disables the folder-name constraint (builtin themes).
func Validate(t Theme, dir, expectedName string) error {
	if len(t.Name) > 40 || !namePattern.MatchString(t.Name) {
		return invalid("name", "expected kebab-case name of at most 40 characters")
	}
	if expectedName != "" && t.Name != expectedName {
		return invalid("name", "name must match theme directory")
	}
	if t.Colors == nil {
		return invalid("colors", "required object")
	}
	for _, key := range ColorKeys {
		value, ok := t.Colors[key]
		if !ok {
			return invalid("colors."+key, "required color")
		}
		if !colorPattern.MatchString(value) {
			return invalid("colors."+key, "expected #RRGGBB")
		}
	}
	keys := make([]string, 0, len(t.Colors))
	for key := range t.Colors {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		known := false
		for _, allowed := range ColorKeys {
			if key == allowed {
				known = true
				break
			}
		}
		if !known {
			return invalid("colors."+key, "unknown color")
		}
	}
	if t.Wallpaper == "" {
		return invalid("wallpaper", "required image path")
	}
	if err := CheckImage(WallpaperPath(t, dir)); err != nil {
		return invalid("wallpaper", err.Error())
	}
	return nil
}

func WallpaperPath(t Theme, dir string) string {
	path := t.Wallpaper
	if !filepath.IsAbs(path) {
		path = filepath.Join(dir, path)
	}
	absolute, err := filepath.Abs(path)
	if err != nil {
		return path
	}
	return absolute
}

// CheckImage decodes the entire image, rejecting truncated files as well as
// unsupported formats. Only standard-library PNG, JPEG and GIF are registered.
func CheckImage(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	_, _, err = image.Decode(f)
	if errors.Is(err, image.ErrFormat) {
		return fmt.Errorf("formato no admitido (PNG, JPEG o GIF)")
	}
	return err
}

type Dirs struct{ Builtin, User string }

type Info struct {
	Name      string            `json:"name"`
	Builtin   bool              `json:"builtin"`
	Active    bool              `json:"active"`
	Valid     bool              `json:"valid"`
	Error     string            `json:"error"`
	Field     string            `json:"field"`
	Dir       string            `json:"dir"`
	File      string            `json:"file"`
	Wallpaper string            `json:"wallpaper"`
	Colors    map[string]string `json:"colors"`
}

// Discover includes invalid themes for diagnostics, ordered builtin then user.
// Hidden directories are save staging/backup folders and never count as themes.
func Discover(dirs Dirs) []Info {
	result := []Info{}
	reserved := map[string]bool{}
	for index, base := range []string{dirs.Builtin, dirs.User} {
		entries, _ := os.ReadDir(base)
		for _, entry := range entries {
			if !entry.IsDir() || entry.Name()[0] == '.' {
				continue
			}
			builtin := index == 0
			if builtin {
				reserved[entry.Name()] = true
			}
			dir, _ := filepath.Abs(filepath.Join(base, entry.Name()))
			info := Info{Name: entry.Name(), Builtin: builtin, Dir: dir, File: filepath.Join(dir, "theme.json"), Colors: map[string]string{}}
			t, err := Load(info.File)
			if err == nil && !builtin {
				err = Validate(t, dir, entry.Name())
			}
			if !builtin && reserved[entry.Name()] {
				err = invalid("name", "name is reserved by a builtin theme")
			}
			if err == nil {
				info.Valid = true
				info.Colors = t.Colors
				info.Wallpaper = WallpaperPath(t, dir)
			} else {
				info.Error = err.Error()
				var validation *ValidationError
				if errors.As(err, &validation) {
					info.Field = validation.Field
				}
			}
			result = append(result, info)
		}
	}
	return result
}

func Find(dirs Dirs, name string) (Info, bool) {
	for _, info := range Discover(dirs) {
		if info.Name == name {
			return info, true
		}
	}
	return Info{}, false
}
