package integration

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// cursorLine is one setting in a file. It only rewrites lines that already
// exist, so Senda never adds a setting the user did not have there.
type cursorLine struct {
	pattern *regexp.Regexp
	render  func(theme string, size int) string
	isSize  bool
}

func keyLine(pattern, format string, isSize bool) cursorLine {
	re := regexp.MustCompile(`(?m)^[ \t]*` + pattern + `.*$`)
	if isSize {
		return cursorLine{re, func(_ string, size int) string { return fmt.Sprintf(format, size) }, true}
	}
	return cursorLine{re, func(theme string, _ int) string { return fmt.Sprintf(format, theme) }, false}
}

var (
	gtkCursorLines = []cursorLine{
		keyLine(`gtk-cursor-theme-name[ \t]*=`, "gtk-cursor-theme-name=%s", false),
		keyLine(`gtk-cursor-theme-size[ \t]*=`, "gtk-cursor-theme-size=%d", true),
	}
	gtk2CursorLines = []cursorLine{
		keyLine(`gtk-cursor-theme-name[ \t]*=`, `gtk-cursor-theme-name="%s"`, false),
		keyLine(`gtk-cursor-theme-size[ \t]*=`, "gtk-cursor-theme-size=%d", true),
	}
	xresourcesCursorLines = []cursorLine{
		keyLine(`Xcursor\.theme[ \t]*:`, "Xcursor.theme: %s", false),
		keyLine(`Xcursor\.size[ \t]*:`, "Xcursor.size: %d", true),
	}
	xsettingsdCursorLines = []cursorLine{
		keyLine(`Gtk/CursorThemeName[ \t]`, `Gtk/CursorThemeName "%s"`, false),
		keyLine(`Gtk/CursorThemeSize[ \t]`, "Gtk/CursorThemeSize %d", true),
	}
	kdeCursorLines = []cursorLine{
		keyLine(`cursorTheme[ \t]*=`, "cursorTheme=%s", false),
		keyLine(`cursorSize[ \t]*=`, "cursorSize=%d", true),
	}
	iconCursorLines = []cursorLine{keyLine(`Inherits[ \t]*=`, "Inherits=%s", false)}
)

// cursorFiles lists the files that toolkits and X clients read their cursor from.
func cursorFiles(home string) map[string][]cursorLine {
	config := filepath.Join(home, ".config")
	return map[string][]cursorLine{
		filepath.Join(config, "gtk-3.0", "settings.ini"):              gtkCursorLines,
		filepath.Join(config, "gtk-4.0", "settings.ini"):              gtkCursorLines,
		filepath.Join(home, ".gtkrc-2.0"):                             gtk2CursorLines,
		filepath.Join(home, ".Xresources"):                            xresourcesCursorLines,
		filepath.Join(home, ".Xdefaults"):                             xresourcesCursorLines,
		filepath.Join(config, "xsettingsd", "xsettingsd.conf"):        xsettingsdCursorLines,
		filepath.Join(config, "kcminputrc"):                           kdeCursorLines,
		filepath.Join(home, ".icons", "default", "index.theme"):       iconCursorLines,
		filepath.Join(home, ".local/share/icons/default/index.theme"): iconCursorLines,
	}
}

// SyncCursorFiles writes the theme and size into the files that already define
// them. An empty theme or a size of 0 leaves that setting alone. It returns the
// files it changed and tries every file even if one fails.
func SyncCursorFiles(home, theme string, size int) ([]string, error) {
	var changed []string
	var errs []error
	for path, lines := range cursorFiles(home) {
		updated, err := syncCursorFile(path, lines, theme, size)
		if err != nil {
			errs = append(errs, err)
		} else if updated {
			changed = append(changed, path)
		}
	}
	return changed, errors.Join(errs...)
}

func syncCursorFile(path string, lines []cursorLine, theme string, size int) (bool, error) {
	// Dotfiles are often symlinks; replacing the link would detach them.
	target, err := filepath.EvalSymlinks(path)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	data, err := os.ReadFile(target)
	if err != nil {
		return false, err
	}
	text := string(data)
	for _, line := range lines {
		if (line.isSize && size == 0) || (!line.isSize && theme == "") {
			continue
		}
		rendered := line.render(theme, size)
		text = line.pattern.ReplaceAllLiteralString(text, rendered)
	}
	if text == string(data) {
		return false, nil
	}
	info, err := os.Stat(target)
	if err != nil {
		return false, err
	}
	temp, err := os.CreateTemp(filepath.Dir(target), ".senda-cursor-*")
	if err != nil {
		return false, err
	}
	defer os.Remove(temp.Name())
	if _, err = temp.WriteString(text); err == nil {
		err = temp.Chmod(info.Mode().Perm())
	}
	if closeErr := temp.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return false, err
	}
	return true, os.Rename(temp.Name(), target)
}

// CursorEnvironment returns the session variables for apps started from now on.
func CursorEnvironment(theme string, size int) []string {
	var env []string
	if theme != "" {
		env = append(env, "XCURSOR_THEME="+theme, "HYPRCURSOR_THEME="+theme)
	}
	if size != 0 {
		value := strconv.Itoa(size)
		env = append(env, "XCURSOR_SIZE="+value, "HYPRCURSOR_SIZE="+value)
	}
	return env
}

// IsCursorXresources reports whether a changed file must be merged with xrdb.
func IsCursorXresources(path string) bool {
	return strings.HasSuffix(path, ".Xresources") || strings.HasSuffix(path, ".Xdefaults")
}

// IsCursorXsettings reports whether a changed file belongs to xsettingsd.
func IsCursorXsettings(path string) bool {
	return strings.HasSuffix(path, "xsettingsd.conf")
}
