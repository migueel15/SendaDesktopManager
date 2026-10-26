package main

import (
	"fmt"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
	"github.com/migueel15/SendaDesktopManager/core/internal/themeexport"
	"github.com/spf13/cobra"
)

func init() { registerThemeSubcommand(themeExportCmd) }

// themeExportRunner runs the reload commands; tests replace it so they never
// signal the developer's real applications.
var themeExportRunner themeexport.Runner = themeexport.ExecRunner

func themeExportCmd() *cobra.Command {
	var asJSON, noReload bool
	cmd := &cobra.Command{Use: "export", Short: "Export the active theme to other applications", Args: cobra.NoArgs, SilenceUsage: true}
	cmd.Flags().BoolVar(&asJSON, "json", false, "Print JSON")
	cmd.Flags().BoolVar(&noReload, "no-reload", false, "Do not ask running applications to reload")
	cmd.RunE = func(cmd *cobra.Command, _ []string) error {
		m := themeManagement{dirs: theme.DefaultDirs(), configFile: paths.ConfigFile()}
		active, err := m.active()
		if err != nil {
			return err
		}
		current, err := m.current(active, false)
		if err != nil {
			return err
		}
		written, err := exportTheme(current.Info, !noReload)
		if err != nil {
			return err
		}
		if asJSON {
			return writeJSON(cmd, map[string]any{"theme": current.Name, "files": written})
		}
		for _, file := range written {
			fmt.Fprintln(cmd.OutOrStdout(), file)
		}
		return nil
	}
	return cmd
}

// exportTheme writes the generated files for info and, if reload is set, asks
// running applications to pick them up.
func exportTheme(info theme.Info, reload bool) ([]string, error) {
	written, err := themeexport.Export(info.Name, info.Colors, themeexport.DefaultDirs())
	if err != nil {
		return nil, fmt.Errorf("export: %w", err)
	}
	if reload {
		themeexport.Reload(themeExportRunner)
	}
	return written, nil
}

// exportActiveTheme is the best-effort export that follows theme changes. A
// failure is reported on stderr but never fails the command that changed the
// theme.
func exportActiveTheme(cmd *cobra.Command, info theme.Info, reload bool) {
	if !info.Valid {
		return
	}
	if _, err := exportTheme(info, reload); err != nil {
		fmt.Fprintln(cmd.ErrOrStderr(), "warning:", err)
	}
}
