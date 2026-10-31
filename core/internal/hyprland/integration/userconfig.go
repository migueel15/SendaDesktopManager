package integration

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
)

// UserSetting says that the user's own configuration defines a value. Value is
// empty when it is not a literal, such as a Lua variable.
type UserSetting struct {
	Value string `json:"value"`
	File  string `json:"file"`
}

// UserConfig holds the text of the files Hyprland really loads from the user's
// configuration: comments are removed and files that nothing requires, or
// whose require is commented out, are not included. Senda's module is skipped.
type UserConfig map[string]string

var (
	luaRequire  = regexp.MustCompile(`require\s*\(?\s*["']([\w./-]+)["']`)
	confSource  = regexp.MustCompile(`(?m)^\s*source\s*=\s*(\S+)`)
	literalText = `(?:"([^"\n]*)"|'([^'\n]*)'|(true|false|yes|no|on|off|-?[\d.]+)\b|([^\s,{}#"']+))`
)

// LoadUserConfig follows require and source from Hyprland's entry file.
func LoadUserConfig() UserConfig {
	hypr := filepath.Dir(hyprConfigFile())
	files := UserConfig{}
	skip, _ := filepath.Abs(ModulePath())
	var visit func(string)
	visit = func(path string) {
		if real, err := filepath.EvalSymlinks(path); err == nil {
			path = real
		}
		if _, seen := files[path]; seen || path == skip {
			return
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return
		}
		text := stripComments(string(data), filepath.Ext(path) == ".lua")
		files[path] = text
		if filepath.Ext(path) == ".lua" {
			for _, m := range luaRequire.FindAllStringSubmatch(text, -1) {
				rel := filepath.FromSlash(strings.ReplaceAll(m[1], ".", "/"))
				visit(filepath.Join(hypr, rel+".lua"))
				visit(filepath.Join(hypr, rel, "init.lua"))
			}
			return
		}
		for _, m := range confSource.FindAllStringSubmatch(text, -1) {
			target := strings.Replace(m[1], "~", filepath.Dir(filepath.Dir(hypr)), 1)
			if !filepath.IsAbs(target) {
				target = filepath.Join(filepath.Dir(path), target)
			}
			visit(target)
		}
	}
	// A symlinked configuration folder must still match Senda's module.
	if real, err := filepath.EvalSymlinks(skip); err == nil {
		skip = real
	}
	visit(filepath.Join(hypr, "hyprland.lua"))
	visit(filepath.Join(hypr, "hyprland.conf"))
	return files
}

// stripComments removes Lua or hyprlang comments, leaving quoted text intact.
func stripComments(text string, lua bool) string {
	var out strings.Builder
	var quote byte
	for i := 0; i < len(text); i++ {
		c := text[i]
		switch {
		case quote != 0:
			if c == '\\' && i+1 < len(text) {
				out.WriteByte(c)
				i++
				c = text[i]
			} else if c == quote || c == '\n' {
				quote = 0
			}
		case lua && strings.HasPrefix(text[i:], "--[["):
			end := strings.Index(text[i:], "]]")
			if end < 0 {
				return out.String()
			}
			out.WriteString(strings.Repeat("\n", strings.Count(text[i:i+end], "\n")))
			i += end + 1
			continue
		case lua && strings.HasPrefix(text[i:], "--"), !lua && c == '#':
			for i < len(text) && text[i] != '\n' {
				i++
			}
			if i < len(text) {
				out.WriteByte('\n')
			}
			continue
		case lua && (c == '"' || c == '\''):
			quote = c
		}
		out.WriteByte(c)
	}
	return out.String()
}

// block returns the bodies of the brace blocks that open after each match.
func block(text string, open *regexp.Regexp) []string {
	var bodies []string
	for _, loc := range open.FindAllStringIndex(text, -1) {
		depth := 1
		for i := loc[1]; i < len(text); i++ {
			switch text[i] {
			case '{':
				depth++
			case '}':
				depth--
			}
			if depth == 0 {
				bodies = append(bodies, text[loc[1]:i])
				break
			}
		}
	}
	return bodies
}

// topLevel removes nested blocks, whose keys belong to another section.
func topLevel(body string) string {
	var out strings.Builder
	depth := 0
	for _, c := range body {
		if c == '{' {
			depth++
		} else if c == '}' {
			depth--
		} else if depth == 0 {
			out.WriteRune(c)
		}
	}
	return out.String()
}

// literal returns the captured value. A bare word is a variable in Lua, so it
// only counts as a value in hyprlang files.
func literal(m []string, file string) string {
	if filepath.Ext(file) != ".lua" && m[4] != "" {
		return m[4]
	}
	for _, v := range m[1:4] {
		if v != "" {
			return v
		}
	}
	return ""
}

// ConfigKey finds key in a section such as ["input"] or ["input", "touchpad"].
// Per-device blocks are never matched because only the named path is entered.
func (c UserConfig) ConfigKey(section []string, key string) (UserSetting, bool) {
	flat := regexp.MustCompile(`(?m)^\s*` + regexp.QuoteMeta(strings.Join(section, ":")+":"+key) + `\s*=\s*` + literalText)
	assign := regexp.MustCompile(`(?:^|[\s,{])` + regexp.QuoteMeta(key) + `\s*=\s*` + literalText)
	for file, text := range c {
		if m := flat.FindStringSubmatch(text); m != nil {
			return UserSetting{Value: literal(m, file), File: file}, true
		}
		bodies := []string{text}
		for _, name := range section {
			open := regexp.MustCompile(`(?:^|[\s,{])` + regexp.QuoteMeta(name) + `\s*=?\s*\{`)
			var next []string
			for _, body := range bodies {
				next = append(next, block(body, open)...)
			}
			bodies = next
		}
		for _, body := range bodies {
			if m := assign.FindStringSubmatch(topLevel(body)); m != nil {
				return UserSetting{Value: literal(m, file), File: file}, true
			}
		}
	}
	return UserSetting{}, false
}

// EnvVar finds an environment variable set by hl.env or env =.
func (c UserConfig) EnvVar(name string) (UserSetting, bool) {
	q := regexp.QuoteMeta(name)
	lua := regexp.MustCompile(`hl\.env\s*\(\s*["']` + q + `["']\s*,\s*` + literalText)
	conf := regexp.MustCompile(`(?m)^\s*env\s*=\s*` + q + `\s*,\s*(\S+)`)
	for file, text := range c {
		if m := lua.FindStringSubmatch(text); m != nil {
			return UserSetting{Value: literal(m, file), File: file}, true
		}
		if m := conf.FindStringSubmatch(text); m != nil {
			return UserSetting{Value: m[1], File: file}, true
		}
	}
	return UserSetting{}, false
}

// Contains finds a command in the configuration, such as hyprctl setcursor.
func (c UserConfig) Contains(pattern *regexp.Regexp) (UserSetting, bool) {
	for file, text := range c {
		if pattern.MatchString(text) {
			return UserSetting{File: file}, true
		}
	}
	return UserSetting{}, false
}

// SessionEnvFiles are the other places where a session variable is commonly
// set outside Hyprland. They are returned as path to text, in KEY=VALUE form.
func SessionEnvFiles() map[string]string {
	config := filepath.Dir(paths.ConfigDir())
	found := map[string]string{}
	globs := []string{filepath.Join(config, "uwsm", "env*"), filepath.Join(config, "environment.d", "*.conf")}
	for _, glob := range globs {
		matches, _ := filepath.Glob(glob)
		for _, path := range matches {
			if data, err := os.ReadFile(path); err == nil {
				found[path] = stripComments(string(data), false)
			}
		}
	}
	return found
}
