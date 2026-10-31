package integration

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Selector says what a user definition looks like in Hyprland's configuration.
// Settings pages share this detection: see ADR 0008.
type Selector struct {
	// LuaCall is the function that defines the setting, such as hl.monitor.
	LuaCall string
	// Field is the table field that names the target, such as output.
	Field string
	// ConfKeyword is the equivalent keyword in hyprland.conf; empty to skip it.
	ConfKeyword string
}

// RuntimeMarker on the line before a call says it adjusts a setting at runtime,
// as a plugin does, and defines nothing.
const RuntimeMarker = "-- senda: runtime"

// Definition is one place where the user's configuration defines a setting.
type Definition struct {
	// Value is the target as written. It is empty for a catch-all.
	Value string `json:"value"`
	// Dynamic means the target is computed, so it can match anything.
	Dynamic bool   `json:"dynamic"`
	File    string `json:"file"`
	Line    int    `json:"line"`
}

// Source returns the file:line shown to the user.
func (d Definition) Source() string { return fmt.Sprintf("%s:%d", d.File, d.Line) }

// UserDefinitions scans the files Hyprland actually loads, starting at its main
// file and following literal require, dofile and source references. Files that
// nothing loads are ignored, and so are the files Senda generates.
func UserDefinitions(sel Selector) ([]Definition, error) {
	main := hyprConfigFile()
	if _, err := os.Stat(main); errors.Is(err, os.ErrNotExist) {
		main = strings.TrimSuffix(main, ".lua") + ".conf"
	}
	scan := definitionScan{sel: sel, root: filepath.Dir(main), seen: map[string]bool{}}
	if err := scan.file(main); err != nil {
		return nil, err
	}
	return scan.found, nil
}

type definitionScan struct {
	sel   Selector
	root  string
	seen  map[string]bool
	found []Definition
}

var (
	luaIncludeRe  = regexp.MustCompile(`\b(require|dofile)\s*[,(]?\s*["']([^"']+)["']`)
	confSourceRe  = regexp.MustCompile(`^\s*source\s*=\s*(.+?)\s*$`)
	luaFieldStart = `\b%s\s*=\s*(?:"([^"]*)"|'([^']*)')`
)

func (s *definitionScan) file(path string) error {
	if s.seen[path] {
		return nil
	}
	s.seen[path] = true
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	text := string(data)
	if strings.HasPrefix(text, moduleHeader) {
		return nil
	}
	if strings.HasSuffix(path, ".conf") {
		return s.conf(path, text)
	}
	return s.lua(path, text)
}

func (s *definitionScan) lua(path, text string) error {
	code := stripLuaComments(text)
	lines := strings.Split(text, "\n")
	if s.sel.LuaCall != "" {
		field := regexp.MustCompile(fmt.Sprintf(luaFieldStart, regexp.QuoteMeta(s.sel.Field)))
		call := regexp.MustCompile(`(^|[^\w.])` + regexp.QuoteMeta(s.sel.LuaCall) + `\s*\(`)
		for _, match := range call.FindAllStringIndex(code, -1) {
			d := Definition{File: path, Line: strings.Count(code[:match[1]], "\n") + 1, Dynamic: true}
			if d.Line >= 2 && strings.TrimSpace(lines[d.Line-2]) == RuntimeMarker {
				continue
			}
			if m := field.FindStringSubmatch(callBody(code[match[1]:])); m != nil {
				d.Value, d.Dynamic = m[1]+m[2], false
			}
			s.found = append(s.found, d)
		}
	}
	for _, m := range luaIncludeRe.FindAllStringSubmatch(code, -1) {
		target := m[2]
		if m[1] == "dofile" {
			if !filepath.IsAbs(target) {
				target = filepath.Join(s.root, target)
			}
		} else {
			base := filepath.Join(s.root, filepath.FromSlash(strings.ReplaceAll(target, ".", "/")))
			target = base + ".lua"
			if _, err := os.Stat(target); err != nil {
				target = filepath.Join(base, "init.lua")
			}
		}
		if err := s.file(target); err != nil {
			return err
		}
	}
	return nil
}

func (s *definitionScan) conf(path, text string) error {
	var keyword *regexp.Regexp
	if s.sel.ConfKeyword != "" {
		keyword = regexp.MustCompile(`^\s*` + regexp.QuoteMeta(s.sel.ConfKeyword) + `\s*=\s*([^,]*)`)
	}
	for i, line := range strings.Split(text, "\n") {
		line, _, _ = strings.Cut(line, "#")
		if keyword != nil {
			if m := keyword.FindStringSubmatch(line); m != nil {
				s.found = append(s.found, Definition{Value: strings.TrimSpace(m[1]), File: path, Line: i + 1})
			}
		}
		m := confSourceRe.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		target := m[1]
		if rest, ok := strings.CutPrefix(target, "~/"); ok {
			home, err := os.UserHomeDir()
			if err != nil {
				return err
			}
			target = filepath.Join(home, rest)
		} else if !filepath.IsAbs(target) {
			target = filepath.Join(filepath.Dir(path), target)
		}
		matches, err := filepath.Glob(target)
		if err != nil {
			return err
		}
		for _, match := range matches {
			if err := s.file(match); err != nil {
				return err
			}
		}
	}
	return nil
}

// stripLuaComments blanks comments and keeps strings and line numbers.
func stripLuaComments(text string) string {
	var out strings.Builder
	for i := 0; i < len(text); {
		c := text[i]
		switch {
		case c == '"' || c == '\'':
			end := stringEnd(text, i)
			out.WriteString(text[i:end])
			i = end
		case strings.HasPrefix(text[i:], "--[["):
			end := strings.Index(text[i:], "]]")
			if end < 0 {
				end = len(text) - i
			} else {
				end += 2
			}
			out.WriteString(strings.Repeat("\n", strings.Count(text[i:i+end], "\n")))
			i += end
		case strings.HasPrefix(text[i:], "--"):
			end := strings.IndexByte(text[i:], '\n')
			if end < 0 {
				return out.String()
			}
			i += end
		default:
			out.WriteByte(c)
			i++
		}
	}
	return out.String()
}

// stringEnd returns the index after the string that starts at i.
func stringEnd(text string, i int) int {
	quote := text[i]
	for j := i + 1; j < len(text); j++ {
		switch text[j] {
		case '\\':
			j++
		case quote, '\n':
			return j + 1
		}
	}
	return len(text)
}

// callBody returns the text up to the parenthesis that closes a call.
func callBody(code string) string {
	depth := 1
	for i := 0; i < len(code); i++ {
		switch code[i] {
		case '"', '\'':
			i = stringEnd(code, i) - 1
		case '(':
			depth++
		case ')':
			if depth--; depth == 0 {
				return code[:i]
			}
		}
	}
	return code
}
