package main

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
	"github.com/spf13/cobra"
)

// Tests never signal the developer's running kitty, Hyprland or Neovim.
func init() {
	themeExportRunner = func(context.Context, string, ...string) error { return nil }
}

func TestThemeExportCommandWritesActiveTheme(t *testing.T) {
	config := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", config)
	repo, _ := filepath.Abs("../../../quickshell")
	t.Setenv("SENDA_HOME", filepath.Dir(repo))
	t.Setenv("SENDA_THEME", "zenda-lavanda")
	cmd := themeExportCmd()
	cmd.SetArgs([]string{"--json", "--no-reload"})
	var out bytes.Buffer
	cmd.SetOut(&out)
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	var result struct {
		Theme string   `json:"theme"`
		Files []string `json:"files"`
	}
	if err := json.Unmarshal(out.Bytes(), &result); err != nil || result.Theme != "zenda-lavanda" {
		t.Fatalf("%s %v", out.String(), err)
	}
	data, err := os.ReadFile(filepath.Join(config, "senda", "generated", "kitty", "senda.conf"))
	if err != nil || !strings.Contains(string(data), "background              #11121D") {
		t.Fatalf("%s %v", data, err)
	}
}

func TestThemeApplyAndDeleteExportEffectiveTheme(t *testing.T) {
	f := newThemeManageFixture(t)
	var exported []string
	f.export = func(_ *cobra.Command, info theme.Info) { exported = append(exported, info.Name) }
	run := func(args ...string) {
		t.Helper()
		cmd := f.command(args[0])
		cmd.SetArgs(append(args[1:], "--no-reload"))
		cmd.SetOut(&bytes.Buffer{})
		if err := cmd.Execute(); err != nil {
			t.Fatal(err)
		}
	}
	run("apply", "custom")
	run("delete", "custom")
	if strings.Join(exported, ",") != "custom,"+theme.DefaultTheme {
		t.Fatal(exported)
	}
}
