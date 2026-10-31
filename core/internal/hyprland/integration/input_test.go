package integration

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func detected(t *testing.T, files map[string]string) map[string]UserSetting {
	t.Helper()
	root := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", root)
	t.Setenv("SENDA_HOME", "")
	for name, text := range files {
		path := filepath.Join(root, "hypr", name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return DetectInput(LoadUserConfig(), SessionEnvFiles())
}

func TestDetectFollowsRequiresAndVariables(t *testing.T) {
	got := detected(t, map[string]string{
		"hyprland.lua":        "require(\"modules.devices\")\nrequire(\"modules.startup\")\n",
		"modules/devices.lua": "hl.config({ input = { kb_layout = \"es\", sensitivity = 0,\n touchpad = { natural_scroll = true, tap_to_click = true } } })\n",
		"modules/startup.lua": "hl.env(\"XCURSOR_THEME\", apps.cursor_theme)\n",
	})
	if got[FieldLayout].Value != "es" || got[FieldSensitivity].Value != "0" || got[FieldNaturalScroll].Value != "true" || got[FieldTapToClick].Value != "true" {
		t.Fatalf("got %+v", got)
	}
	if c, ok := got[FieldCursorTheme]; !ok || c.Value != "" {
		t.Fatalf("a variable is managed without a literal value: %+v", got)
	}
}

func TestDetectFindsNothingForCleanUsers(t *testing.T) {
	got := detected(t, map[string]string{
		"hyprland.lua":      "-- hl.config({ input = { kb_layout = \"es\" } })\n--require(\"modules.old\")\nhl.device({ name = \"m\", sensitivity = 0.5 })\nhl.config({ input = { tablet = { sensitivity = 1 } } })\nrequire(\"modules.senda\")\n",
		"modules/old.lua":   "hl.env(\"XCURSOR_THEME\", \"x\")\n",
		"modules/senda.lua": "hl.config({ input = { kb_layout = \"us\" } })\n",
		"orphan.lua":        "hl.config({ input = { kb_layout = \"fr\" } })\n",
	})
	if len(got) != 0 {
		t.Fatalf("clean configuration detected: %+v", got)
	}
}

func TestDetectHyprlangAndSetcursor(t *testing.T) {
	got := detected(t, map[string]string{
		"hyprland.conf": "source = ./extra.conf\ninput {\n kb_layout = us\n device {\n  sensitivity = 1\n }\n touchpad {\n  tap-to-click = false\n }\n}\n",
		"extra.conf":    "exec-once = hyprctl setcursor Foo 24\n",
	})
	if got[FieldLayout].Value != "us" || got[FieldTapToClick].Value != "false" {
		t.Fatalf("got %+v", got)
	}
	if _, ok := got[FieldSensitivity]; ok {
		t.Fatal("device block counted as global")
	}
	if _, ok := got[FieldCursorTheme]; !ok {
		t.Fatal("setcursor not detected")
	}
}

func TestRenderOmitsUnsetAndUserFields(t *testing.T) {
	if out := renderInput(InputSettings{}, 24); out != "" {
		t.Fatalf("no choice must generate nothing: %q", out)
	}
	s := InputSettings{Layout: "es", CursorTheme: "Bibata", NaturalScroll: "true"}.withoutUser(map[string]UserSetting{FieldLayout: {Value: "us"}})
	out := renderInput(s, 24)
	if strings.Contains(out, "kb_layout") || !strings.Contains(out, "natural_scroll = true") || !strings.Contains(out, "hyprctl setcursor 'Bibata' 24") || !strings.Contains(out, "cursor-theme 'Bibata'") {
		t.Fatalf("got %q", out)
	}
}

func TestValidateAndThemes(t *testing.T) {
	for _, s := range []InputSettings{{Layout: `es" } }) os.execute("x`}, {Sensitivity: "2"}, {TapToClick: "maybe"}, {CursorTheme: "a\nb"}} {
		if s.Validate() == nil {
			t.Fatalf("accepted %+v", s)
		}
	}
	dir := t.TempDir()
	for _, p := range []string{"Bibata/cursors", "hicolor/apps", "default/cursors"} {
		if err := os.MkdirAll(filepath.Join(dir, p), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if got := listCursorThemes([]string{dir}); !reflect.DeepEqual(got, []string{"Bibata"}) {
		t.Fatalf("got %v", got)
	}
}

func TestPointerFields(t *testing.T) {
	got := detected(t, map[string]string{"hyprland.lua": "hl.config({ input = { accel_profile = \"flat\", follow_mouse = 1, touchpad = { scroll_factor = 0.4, disable_while_typing = true } } })\nhl.device({ name = \"m\", accel_profile = \"flat\" })\n"})
	if got[FieldAccelProfile].Value != "flat" || got[FieldFollowMouse].Value != "1" || got[FieldScrollFactor].Value != "0.4" || got[FieldDisableTyping].Value != "true" {
		t.Fatalf("got %+v", got)
	}
	device := detected(t, map[string]string{"hyprland.lua": "hl.device({ name = \"m\", accel_profile = \"flat\" })\n"})
	if len(device) != 0 {
		t.Fatalf("device block counted as global: %+v", device)
	}
	out := renderInput(InputSettings{AccelProfile: "flat", FollowMouse: "2", ScrollFactor: "0.5"}, 24)
	for _, want := range []string{`accel_profile = "flat"`, "follow_mouse = 2", "scroll_factor = 0.5"} {
		if !strings.Contains(out, want) {
			t.Fatalf("%q missing in %q", want, out)
		}
	}
	for _, bad := range []InputSettings{{AccelProfile: "x"}, {FollowMouse: "9"}, {ScrollFactor: "0"}} {
		if bad.Validate() == nil {
			t.Fatalf("accepted %+v", bad)
		}
	}
}

func TestDefaultsAndSystemLayout(t *testing.T) {
	dir := t.TempDir()
	xorg, console := filepath.Join(dir, "x"), filepath.Join(dir, "v")
	os.WriteFile(console, []byte("KEYMAP=es\n"), 0o644)
	if got := SystemLayout(xorg, console); got != "es" {
		t.Fatalf("vconsole: %q", got)
	}
	os.WriteFile(xorg, []byte("Section \"InputClass\"\n  Option \"XkbLayout\" \"us,es\"\n"), 0o644)
	if got := SystemLayout(xorg, console); got != "us,es" {
		t.Fatalf("xorg: %q", got)
	}
	d := InputSettings{TapToClick: "false"}.WithDefaults()
	if d.Sensitivity != "0" || d.AccelProfile != "flat" || d.FollowMouse != "1" || d.NaturalScroll != "true" || d.TapToClick != "false" {
		t.Fatalf("got %+v", d)
	}
	if got := d.withoutUser(map[string]UserSetting{FieldAccelProfile: {}}); got.AccelProfile != "" {
		t.Fatal("a default must not override the user")
	}
}

func TestDetectGsettingsCursor(t *testing.T) {
	got := detected(t, map[string]string{"hyprland.lua": "hl.exec_cmd(\"gsettings set org.gnome.desktop.interface cursor_theme\" .. \" \" .. x)\n"})
	if _, ok := got[FieldCursorTheme]; !ok {
		t.Fatal("gsettings not detected")
	}
}

func TestCursorSize(t *testing.T) {
	got := detected(t, map[string]string{"hyprland.lua": "hl.env(\"XCURSOR_SIZE\", \"26\")\n"})
	if got[FieldCursorSize].Value != "26" {
		t.Fatalf("got %+v", got)
	}
	if _, ok := got[FieldCursorTheme]; ok {
		t.Fatal("size must not manage the theme")
	}
	out := renderInput(InputSettings{CursorTheme: "B", CursorSize: "32"}, 24)
	for _, want := range []string{`hl.env("XCURSOR_SIZE", "32")`, "setcursor 'B' 32", "cursor-size 32"} {
		if !strings.Contains(out, want) {
			t.Fatalf("%q missing in %q", want, out)
		}
	}
	if (InputSettings{CursorSize: "4"}).Validate() == nil {
		t.Fatal("accepted a small size")
	}
}
