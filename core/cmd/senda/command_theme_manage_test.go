package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
	"github.com/spf13/cobra"
)

type themeManageFixture struct {
	themeManagement
	notices, reloads int
	body             string
}

func newThemeManageFixture(t *testing.T) *themeManageFixture {
	t.Helper()
	t.Setenv("SENDA_THEME", "")
	dir := t.TempDir()
	f := &themeManageFixture{themeManagement: themeManagement{dirs: theme.Dirs{Builtin: filepath.Join(dir, "builtin"), User: filepath.Join(dir, "user")}, configFile: filepath.Join(dir, "config")}}
	f.notify = func(title, body string) error {
		f.notices++
		f.body = title + ": " + body
		return errors.New("notification unavailable")
	}
	f.reload = func(*cobra.Command) error { f.reloads++; return errors.New("shell unavailable") }
	f.add(t, f.dirs.Builtin, theme.DefaultTheme, true)
	f.add(t, f.dirs.User, "custom", true)
	f.add(t, f.dirs.User, "broken", false)
	return f
}

func (f *themeManageFixture) add(t *testing.T, base, name string, valid bool) {
	t.Helper()
	dir := filepath.Join(base, name)
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	img, err := os.Create(filepath.Join(dir, "wallpaper.png"))
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(img, image.NewRGBA(image.Rect(0, 0, 1, 1))); err != nil {
		t.Fatal(err)
	}
	img.Close()
	colors := map[string]string{}
	for _, key := range theme.ColorKeys {
		colors[key] = "#123456"
	}
	if !valid {
		colors["primary"] = "bad"
	}
	data, err := json.Marshal(theme.Theme{Name: name, Wallpaper: "wallpaper.png", Colors: colors})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "theme.json"), data, 0600); err != nil {
		t.Fatal(err)
	}
}

func (f *themeManageFixture) run(args ...string) (string, string, error) {
	root := &cobra.Command{Use: "theme", SilenceUsage: true}
	for _, name := range []string{"list", "validate", "current", "apply", "delete"} {
		root.AddCommand(f.command(name))
	}
	var out, stderr bytes.Buffer
	root.SetOut(&out)
	root.SetErr(&stderr)
	root.SetArgs(args)
	err := root.Execute()
	return out.String(), stderr.String(), err
}

func TestThemeManageList(t *testing.T) {
	f := newThemeManageFixture(t)
	out, _, err := f.run("list", "--json")
	if err != nil {
		t.Fatal(err)
	}
	var infos []theme.Info
	if err := json.Unmarshal([]byte(out), &infos); err != nil {
		t.Fatal(err)
	}
	if len(infos) != 3 || !infos[0].Builtin || !infos[0].Active || infos[1].Valid || infos[1].Field != "colors.primary" || !infos[2].Valid {
		t.Fatal(out)
	}
	out, _, err = f.run("list")
	if err != nil || !strings.Contains(out, "NAME") || !strings.Contains(out, "custom") {
		t.Fatalf("%s %v", out, err)
	}
	f.dirs = theme.Dirs{}
	out, _, err = f.run("list", "--json")
	if err != nil || strings.TrimSpace(out) != "[]" {
		t.Fatalf("%s %v", out, err)
	}
}

func TestThemeManageValidate(t *testing.T) {
	f := newThemeManageFixture(t)
	external := t.TempDir()
	f.add(t, external, "external", true)
	for _, target := range []string{"custom", filepath.Join(f.dirs.User, "custom", "theme.json"), filepath.Join(external, "external", "theme.json")} {
		out, _, err := f.run("validate", target, "--json")
		if err != nil {
			t.Fatal(err)
		}
		var info theme.Info
		if err := json.Unmarshal([]byte(out), &info); err != nil || !info.Valid {
			t.Fatal(out, err)
		}
	}
	for _, target := range []string{"broken", "missing", filepath.Join(t.TempDir(), "theme.json")} {
		out, stderr, err := f.run("validate", target, "--json", "--notify")
		var info theme.Info
		if err == nil || json.Unmarshal([]byte(out), &info) != nil || info.Valid || info.Field == "" || !strings.Contains(stderr, info.Field+":") || !strings.Contains(f.body, "Tema no válido") {
			t.Fatalf("%s %s %v", out, stderr, err)
		}
	}
	if f.notices != 3 {
		t.Fatal(f.notices)
	}
	f.add(t, f.dirs.User, "mismatch", true)
	data, err := os.ReadFile(filepath.Join(f.dirs.User, "custom", "theme.json"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(f.dirs.User, "mismatch", "theme.json"), data, 0600); err != nil {
		t.Fatal(err)
	}
	if _, stderr, err := f.run("validate", filepath.Join(f.dirs.User, "mismatch", "theme.json")); err == nil || !strings.Contains(stderr, "name:") {
		t.Fatal(stderr, err)
	}
}

func TestThemeManageCurrent(t *testing.T) {
	for _, active := range []string{"", "custom", "missing", "broken"} {
		t.Run("active-"+active, func(t *testing.T) {
			f := newThemeManageFixture(t)
			if err := config.Set(f.configFile, map[string]string{"SENDA_THEME": active}); err != nil {
				t.Fatal(err)
			}
			out, _, err := f.run("current", "--json", "--notify")
			if err != nil {
				t.Fatal(err)
			}
			var got struct {
				theme.Info
				Fallback bool
				Warning  string
			}
			if err := json.Unmarshal([]byte(out), &got); err != nil {
				t.Fatal(err)
			}
			fallback := active == "missing" || active == "broken"
			want := theme.DefaultTheme
			if active == "custom" {
				want = active
			}
			if got.Name != want || !got.Valid || !got.Active || got.Fallback != fallback || (got.Warning != "") != fallback || (f.notices > 0) != fallback {
				t.Fatal(out, f.notices)
			}
		})
	}
	f := newThemeManageFixture(t)
	t.Setenv("SENDA_THEME", "broken")
	f.add(t, f.dirs.Builtin, theme.DefaultTheme, false)
	if _, stderr, err := f.run("current", "--json"); err == nil || !strings.Contains(stderr, "colors.primary:") {
		t.Fatal(stderr, err)
	}
}

func TestThemeManageApplyDelete(t *testing.T) {
	f := newThemeManageFixture(t)
	for _, name := range []string{"broken", "missing", "../custom"} {
		if _, _, err := f.run("apply", name); err == nil {
			t.Fatal("accepted", name)
		}
	}
	if _, _, err := f.run("apply", "custom"); err != nil {
		t.Fatal(err)
	}
	values, err := config.Load(f.configFile)
	if err != nil || values["SENDA_THEME"] != "custom" || f.reloads != 1 {
		t.Fatal(values, err, f.reloads)
	}
	if _, _, err := f.run("delete", "custom"); err != nil {
		t.Fatal(err)
	}
	values, err = config.Load(f.configFile)
	if err != nil || values["SENDA_THEME"] != theme.DefaultTheme || f.reloads != 2 {
		t.Fatal(values, err, f.reloads)
	}
	if _, err := os.Stat(filepath.Join(f.dirs.User, "custom")); !os.IsNotExist(err) {
		t.Fatal(err)
	}
	for _, name := range []string{theme.DefaultTheme, "missing", "../builtin"} {
		if _, _, err := f.run("delete", name); err == nil {
			t.Fatal("deleted", name)
		}
	}
	if _, _, err := f.run("delete", "broken"); err != nil || f.reloads != 2 {
		t.Fatal(err, f.reloads)
	}
	f.add(t, f.dirs.User, "custom", true)
	for _, action := range []string{"apply", "delete"} {
		if _, _, err := f.run(action, "custom", "--no-reload"); err != nil || f.reloads != 2 {
			t.Fatal(err, f.reloads)
		}
	}
}

func TestThemeManageEnvironmentAndConfigErrors(t *testing.T) {
	f := newThemeManageFixture(t)
	if err := config.Set(f.configFile, map[string]string{"SENDA_THEME": "custom"}); err != nil {
		t.Fatal(err)
	}
	t.Setenv("SENDA_THEME", theme.DefaultTheme)
	out, _, err := f.run("current")
	if err != nil || strings.TrimSpace(out) != theme.DefaultTheme {
		t.Fatal(out, err)
	}
	if err := os.WriteFile(f.configFile, []byte("invalid config"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, stderr, err := f.run("apply", "custom"); err == nil || !strings.Contains(stderr, "SENDA_THEME:") || f.reloads != 0 {
		t.Fatal(stderr, err)
	}
	t.Setenv("SENDA_THEME", "")
	if _, stderr, err := f.run("current"); err == nil || !strings.Contains(stderr, "SENDA_THEME:") {
		t.Fatal(stderr, err)
	}
}

func TestThemeImageValidationModes(t *testing.T) {
	for _, kind := range []string{"truncated", "unsupported", "missing"} {
		t.Run(kind, func(t *testing.T) {
			f := newThemeManageFixture(t)
			dir := filepath.Join(f.dirs.User, "custom")
			wallpaper := filepath.Join(dir, "wallpaper.png")
			data, err := os.ReadFile(wallpaper)
			if err != nil {
				t.Fatal(err)
			}
			switch kind {
			case "truncated":
				data = data[:33] // PNG signature and IHDR only.
			case "unsupported":
				data = []byte("not an image")
			}
			if err := os.WriteFile(wallpaper, data, 0600); err != nil {
				t.Fatal(err)
			}
			if kind == "missing" {
				if err := os.Remove(wallpaper); err != nil {
					t.Fatal(err)
				}
			}
			out, _, err := f.run("list", "--json")
			if err != nil {
				t.Fatal(err)
			}
			var infos []theme.Info
			if err := json.Unmarshal([]byte(out), &infos); err != nil {
				t.Fatal(err)
			}
			if infos[2].Valid != (kind == "truncated") {
				t.Fatal(out)
			}
			out, _, err = f.run("apply", "custom", "--json", "--no-reload")
			if kind == "truncated" {
				var info theme.Info
				if err != nil || json.Unmarshal([]byte(out), &info) != nil || !info.Valid || !info.Active || info.Name != "custom" || info.Wallpaper != wallpaper {
					t.Fatal(out, err)
				}
			} else if err == nil || !strings.Contains(err.Error(), "wallpaper:") {
				t.Fatal(err)
			}
			t.Setenv("SENDA_THEME", "custom")
			out, _, err = f.run("current", "--json")
			var current currentThemeResult
			if err != nil || json.Unmarshal([]byte(out), &current) != nil || current.Fallback != (kind != "truncated") {
				t.Fatal(out, err)
			}
			for _, target := range []string{"custom", filepath.Join(dir, "theme.json")} {
				if _, _, err := f.run("validate", target); err == nil || !strings.Contains(err.Error(), "wallpaper:") {
					t.Fatal(target, err)
				}
			}
		})
	}
}

func TestThemeApplyJSONEffectiveSelection(t *testing.T) {
	for _, override := range []string{"", theme.DefaultTheme, "missing"} {
		t.Run("override-"+override, func(t *testing.T) {
			f := newThemeManageFixture(t)
			t.Setenv("SENDA_THEME", override)
			out, _, err := f.run("apply", "custom", "--json", "--no-reload")
			if err != nil {
				t.Fatal(err)
			}
			current, _, err := f.run("current", "--json")
			if err != nil || out != current || f.reloads != 0 {
				t.Fatal(out, current, err, f.reloads)
			}
			values, err := config.Load(f.configFile)
			if err != nil || values["SENDA_THEME"] != "custom" {
				t.Fatal(values, err)
			}
		})
	}
}
