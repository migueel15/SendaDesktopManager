package main

import (
	"github.com/spf13/cobra"
	"testing"
)

func TestThemeSubcommandRegistration(t *testing.T) {
	previous := themeSubcommands
	defer func() { themeSubcommands = previous }()
	themeSubcommands = nil
	registerThemeSubcommand(func() *cobra.Command { return &cobra.Command{Use: "example"} })
	cmd := themeCmd()
	if len(cmd.Commands()) != 1 || cmd.Commands()[0].Name() != "example" {
		t.Fatal(cmd.Commands())
	}
}

func TestReloadThemeWithoutShell(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	if err := reloadShellTheme(&cobra.Command{}); err != nil {
		t.Fatal(err)
	}
}
