package themeexport

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
)

func builtinThemes(t *testing.T) []theme.Theme {
	t.Helper()
	files, _ := filepath.Glob("../../../quickshell/themes/*/theme.json")
	if len(files) < 2 {
		t.Fatalf("builtin themes not found: %v", files)
	}
	var result []theme.Theme
	for _, file := range files {
		value, err := theme.Load(file)
		if err != nil {
			t.Fatal(file, err)
		}
		result = append(result, value)
	}
	return result
}

func TestDeriveGivesSixteenDistinctColors(t *testing.T) {
	for _, value := range builtinThemes(t) {
		p := Derive(value.Name, value.Colors)
		if len(p.ANSI) != 16 || !p.Dark {
			t.Fatalf("%s: %v dark=%t", value.Name, p.ANSI, p.Dark)
		}
		seen := map[string]bool{}
		for i, color := range p.ANSI {
			if _, err := parseHex(color); err != nil || seen[color] {
				t.Fatalf("%s: color%d %q repeated or invalid: %v", value.Name, i, color, p.ANSI)
			}
			seen[color] = true
		}
		if p.T["red"] != value.Colors["error"] || p.T["green"] != value.Colors["success"] {
			t.Fatalf("%s: semantic colors not kept: %v", value.Name, p.T)
		}
	}
}

func TestRenderBuiltinTemplates(t *testing.T) {
	want := []string{"kitty/senda.conf", "gtk-3.0/gtk.css", "gtk-4.0/gtk.css", "qt/senda.conf", "hyprland/colors.conf", "nvim/colors/senda.lua", "nvim/lua/lualine/themes/senda.lua", "kde/senda.colors"}
	for _, value := range builtinThemes(t) {
		rendered, err := Render(Derive(value.Name, value.Colors), "")
		if err != nil {
			t.Fatal(err)
		}
		for _, path := range want {
			content := string(rendered[filepath.FromSlash(path)])
			if content == "" || strings.Contains(content, "{{") || strings.Contains(content, "<no value>") {
				t.Fatalf("%s %s:\n%s", value.Name, path, content)
			}
			if !strings.Contains(content, value.Name) {
				t.Fatalf("%s %s: missing theme name", value.Name, path)
			}
		}
		qt := string(rendered[filepath.FromSlash("qt/senda.conf")])
		for _, line := range strings.Split(qt, "\n") {
			if strings.Contains(line, "_colors=") && strings.Count(line, "#ff") != 21 {
				t.Fatalf("qt roles: %s", line)
			}
		}
	}
}

func TestExportUserTemplatesOverrideAndExtend(t *testing.T) {
	value := builtinThemes(t)[0]
	dirs := Dirs{Templates: t.TempDir(), Output: filepath.Join(t.TempDir(), "generated")}
	write := func(path, content string) {
		t.Helper()
		full := filepath.Join(dirs.Templates, path)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("kitty/senda.conf", "background {{.C.base}}\n")
	write("rofi/colors.rasi", "* { bg: {{.C.background}}; red: {{.T.red}}; }\n")
	written, err := Export(value.Name, value.Colors, dirs)
	if err != nil {
		t.Fatal(err)
	}
	if len(written) != 9 {
		t.Fatal(written)
	}
	kitty, _ := os.ReadFile(filepath.Join(dirs.Output, "kitty", "senda.conf"))
	if string(kitty) != "background "+value.Colors["base"]+"\n" {
		t.Fatalf("override ignored: %s", kitty)
	}
	rofi, _ := os.ReadFile(filepath.Join(dirs.Output, "rofi", "colors.rasi"))
	if !strings.Contains(string(rofi), value.Colors["error"]) {
		t.Fatalf("user template not rendered: %s", rofi)
	}
	leftovers, _ := filepath.Glob(filepath.Join(dirs.Output, "kitty", ".*"))
	if len(leftovers) != 0 {
		t.Fatal(leftovers)
	}
}

func TestExportRejectsBrokenUserTemplate(t *testing.T) {
	value := builtinThemes(t)[0]
	dirs := Dirs{Templates: t.TempDir(), Output: t.TempDir()}
	if err := os.WriteFile(filepath.Join(dirs.Templates, "bad.conf"), []byte("{{.C.missing}}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Export(value.Name, value.Colors, dirs); err == nil || !strings.Contains(err.Error(), "bad.conf") {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dirs.Templates, "bad.conf"), []byte(`{{mix "red" .C.base 0.5}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Export(value.Name, value.Colors, dirs); err == nil {
		t.Fatal("expected error for invalid color")
	}
}

func TestReloadTargetsRunningApplications(t *testing.T) {
	runtime := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", runtime)
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "test")
	if err := os.WriteFile(filepath.Join(runtime, "nvim.123.0"), nil, 0o600); err != nil {
		t.Fatal(err)
	}
	var calls []string
	Reload(func(_ context.Context, name string, args ...string) error {
		calls = append(calls, name+" "+strings.Join(args, " "))
		return nil
	})
	got := strings.Join(calls, "\n")
	for _, want := range []string{"pkill -USR1 -x kitty", "hyprctl reload", "nvim --server " + filepath.Join(runtime, "nvim.123.0")} {
		if !strings.Contains(got, want) {
			t.Fatalf("missing %q in:\n%s", want, got)
		}
	}
}

func TestCatppuccinNamesFollowThemeVariables(t *testing.T) {
	for _, value := range builtinThemes(t) {
		k := Derive(value.Name, value.Colors).K
		for name, key := range map[string]string{"red": "error", "green": "success", "yellow": "warning", "blue": "primary", "lavender": "secondary", "sapphire": "info", "base": "surface"} {
			if k[name] != value.Colors[key] {
				t.Fatalf("%s: %s = %s, want %s %s", value.Name, name, k[name], key, value.Colors[key])
			}
		}
		for _, name := range catppuccinAccents {
			if _, err := parseHex(k[name]); err != nil {
				t.Fatal(name, err)
			}
		}
	}
}
