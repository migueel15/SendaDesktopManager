package integration

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func hyprDir(t *testing.T, files map[string]string) {
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
}

func TestUserDefinitionsFollowsLoadedFiles(t *testing.T) {
	hyprDir(t, map[string]string{
		"hyprland.lua": "require(\"modules.monitors\")\nrequire(\"modules.senda\")\n-- require(\"modules.commented\")\n",
		"modules/monitors.lua": `local c = require("modules.config")
hl.monitor({
	-- output = "HDMI-A-9",
	output = "desc:BNQ BenQ",
	mirror = c.mirror and "x" or "",
})
hl.monitor({ output = "", mode = "preferred" })
hl.monitor({ output = c.name })
-- hl.monitor({ output = "DP-9" })
`,
		"modules/config.lua":    "return {}\n",
		"modules/commented.lua": `hl.monitor({ output = "DP-8" })`,
		"modules/unused.lua":    `hl.monitor({ output = "DP-7" })`,
		"modules/senda.lua":     "-- Generado por Senda.\nhl.monitor({ output = \"DP-6\" })\n",
	})
	defs, err := UserDefinitions(MonitorSelector)
	if err != nil {
		t.Fatal(err)
	}
	if len(defs) != 3 || defs[0].Value != "desc:BNQ BenQ" || defs[0].Line != 2 || defs[1].Value != "" || defs[1].Dynamic || !defs[2].Dynamic {
		t.Fatalf("definiciones = %+v", defs)
	}
}

func TestUserDefinitionsReadsConf(t *testing.T) {
	hyprDir(t, map[string]string{
		"hyprland.conf": "source = ./extra.conf\n#monitor = DP-9,preferred\n",
		"extra.conf":    "monitor = DP-1, 1920x1080@60, 0x0, 1\n",
	})
	defs, err := UserDefinitions(MonitorSelector)
	if err != nil || len(defs) != 1 || defs[0].Value != "DP-1" {
		t.Fatalf("definiciones = %+v, %v", defs, err)
	}
}

func TestUserDefinitionsEmptyWithoutConfig(t *testing.T) {
	hyprDir(t, nil)
	if defs, err := UserDefinitions(MonitorSelector); err != nil || len(defs) != 0 {
		t.Fatalf("definiciones = %+v, %v", defs, err)
	}
}

func TestClaims(t *testing.T) {
	defs := []Definition{{Value: ""}, {Value: "desc:Foo"}, {Value: "DP-2"}}
	for _, tc := range []struct {
		name, desc string
		want       bool
	}{{"DP-1", "Foo", true}, {"DP-2", "", true}, {"DP-3", "Bar", false}} {
		if got := claimedBy(defs, tc.name, tc.desc) != nil; got != tc.want {
			t.Errorf("%s: %t", tc.name, got)
		}
	}
	if claimedBy([]Definition{{Dynamic: true}}, "DP-3", "") == nil {
		t.Error("un destino calculado debe reclamar todas las pantallas")
	}
}

func TestRenderSkipsNothingButValidates(t *testing.T) {
	s := DefaultSettings()
	s.Displays = []DisplayRule{{Name: "DP-1", Description: "Foo", Mode: "1920x1080@60", Position: "-1920x0", Scale: 1.25}}
	lua, _, err := Render(s, "/usr/bin/senda")
	if err != nil {
		t.Fatal(err)
	}
	want := `hl.monitor({ output = "desc:Foo", mode = "1920x1080@60", position = "-1920x0", scale = "1.25", transform = 0 })`
	if DisplayLines(lua) != want {
		t.Fatalf("módulo: %s", DisplayLines(lua))
	}
	s.Displays[0].Mode = `x"})`
	if _, _, err := Render(s, "/usr/bin/senda"); err == nil {
		t.Fatal("modo inválido aceptado")
	}
}

const twoMonitors = `[{"name":"DP-1","description":"Foo","width":1920,"height":1080,"refreshRate":59.95,"x":0,"y":0,"scale":1,"mirrorOf":"none","availableModes":["1920x1080@59.95Hz"]},
{"name":"DP-2","description":"Bar","width":2560,"height":1440,"refreshRate":144,"x":1920,"y":0,"scale":1,"mirrorOf":"none"}]`

func monitorsRun(_ context.Context, _ io.Reader, _ string, args ...string) ([]byte, error) {
	if strings.Join(args, " ") == "-j monitors all" {
		return []byte(twoMonitors), nil
	}
	return nil, os.ErrInvalid
}

func TestChangeDisplay(t *testing.T) {
	hyprDir(t, map[string]string{"hyprland.lua": `hl.monitor({ output = "desc:Bar" })`})
	ctx := context.Background()
	if _, err := ChangeDisplay(ctx, monitorsRun, nil, "DP-2", DisplayChange{Position: "0x0"}); err == nil || !strings.Contains(err.Error(), "hyprland.lua:1") {
		t.Fatalf("debe rechazar la pantalla del usuario: %v", err)
	}
	rules, err := ChangeDisplay(ctx, monitorsRun, nil, "DP-1", DisplayChange{Position: "100x0"})
	if err != nil || len(rules) != 1 || rules[0].Mode != "1920x1080@59.95" || rules[0].Position != "100x0" {
		t.Fatalf("reglas = %+v, %v", rules, err)
	}
	self := "DP-1"
	if _, err := ChangeDisplay(ctx, monitorsRun, rules, "DP-1", DisplayChange{Mirror: &self}); err == nil {
		t.Fatal("se ha duplicado a sí misma")
	}
	target := "DP-2"
	rules, err = ChangeDisplay(ctx, monitorsRun, rules, "DP-1", DisplayChange{Mirror: &target})
	if err != nil || rules[0].Mirror != "desc:Bar" {
		t.Fatalf("reglas = %+v, %v", rules, err)
	}
	state, err := InspectDisplays(ctx, monitorsRun, rules, true)
	if err != nil || state.Displays[0].ManagedBy != "senda" || state.Displays[1].ManagedBy != "user" || state.Displays[1].Source == "" {
		t.Fatalf("estado = %+v, %v", state, err)
	}
	if rules, err = ResetDisplay(ctx, monitorsRun, rules, "DP-1"); err != nil || len(rules) != 0 {
		t.Fatalf("reglas = %+v, %v", rules, err)
	}
}

func TestReadSettingsHidesClaimedRules(t *testing.T) {
	hyprDir(t, map[string]string{"hyprland.lua": `hl.monitor({ output = "DP-1" })`})
	root := os.Getenv("XDG_CONFIG_HOME")
	if err := os.MkdirAll(filepath.Join(root, "senda"), 0o755); err != nil {
		t.Fatal(err)
	}
	stored := `[{"name":"DP-1","mode":"preferred","position":"0x0","scale":1},{"name":"DP-2","mode":"preferred","position":"0x0","scale":1}]`
	if err := StoreDisplays(filepath.Join(root, "senda", "config"), mustParse(t, stored), nil); err != nil {
		t.Fatal(err)
	}
	s, err := ReadSettings()
	if err != nil || len(s.Displays) != 1 || s.Displays[0].Name != "DP-2" {
		t.Fatalf("ajustes = %+v, %v", s.Displays, err)
	}
}

func mustParse(t *testing.T, value string) []DisplayRule {
	t.Helper()
	rules, err := ParseDisplays(value)
	if err != nil {
		t.Fatal(err)
	}
	return rules
}
