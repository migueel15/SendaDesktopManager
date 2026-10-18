package config

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

var keyPattern = regexp.MustCompile(`^[A-Z][A-Z0-9_]*$`)

// Set updates keys in the settings file at path and keeps every other line,
// including comments and keys it does not know. An empty value removes the key.
// The file is replaced atomically with owner-only permissions. Set refuses to
// rewrite a file that Load cannot parse, so it never discards a broken file's
// contents silently.
func Set(path string, changes map[string]string) error {
	for key := range changes {
		if !keyPattern.MatchString(key) {
			return fmt.Errorf("invalid setting name %q", key)
		}
	}

	existing, err := os.ReadFile(path)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		existing = nil
	case err != nil:
		return err
	default:
		if _, err := Load(path); err != nil {
			return fmt.Errorf("refusing to rewrite an invalid config file: %w", err)
		}
	}

	return writeAtomic(path, []byte(rewrite(string(existing), changes)))
}

// rewrite applies changes to the text of a settings file and returns the new
// text. Lines that are not changed are copied exactly.
func rewrite(text string, changes map[string]string) string {
	var lines []string
	written := map[string]bool{}

	text = strings.TrimSuffix(text, "\n")
	var existing []string
	if text != "" {
		existing = strings.Split(text, "\n")
	}

	for _, line := range existing {
		key, ok := lineKey(line)
		value, changed := changes[key]
		if !ok || !changed {
			lines = append(lines, line)
			continue
		}
		written[key] = true
		if value != "" {
			lines = append(lines, formatLine(key, value))
		}
	}

	var added []string
	for key := range changes {
		if !written[key] && changes[key] != "" {
			added = append(added, key)
		}
	}
	sort.Strings(added)
	for _, key := range added {
		lines = append(lines, formatLine(key, changes[key]))
	}

	if len(lines) == 0 {
		return ""
	}
	return strings.Join(lines, "\n") + "\n"
}

// lineKey returns the key of a KEY=VALUE line, or false for blank lines,
// comments, and lines without a key.
func lineKey(line string) (string, bool) {
	trimmed := strings.TrimSpace(line)
	if trimmed == "" || strings.HasPrefix(trimmed, "#") {
		return "", false
	}
	trimmed = strings.TrimPrefix(trimmed, "export ")
	key, _, ok := strings.Cut(trimmed, "=")
	key = strings.TrimSpace(key)
	return key, ok && key != ""
}

// formatLine writes values in double quotes with Go escapes, which parseValue
// reads back exactly, so spaces and '#' in values survive a round trip.
func formatLine(key, value string) string {
	return key + "=" + strconv.Quote(value)
}

func writeAtomic(path string, data []byte) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}

	temp, err := os.CreateTemp(dir, ".config-*.tmp")
	if err != nil {
		return err
	}
	defer os.Remove(temp.Name())

	if err := temp.Chmod(0o600); err != nil {
		temp.Close()
		return err
	}
	if _, err := temp.Write(data); err != nil {
		temp.Close()
		return err
	}
	if err := temp.Close(); err != nil {
		return err
	}
	return os.Rename(temp.Name(), path)
}
