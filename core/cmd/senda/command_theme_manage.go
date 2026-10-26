package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/notify"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
	"github.com/spf13/cobra"
)

type themeManagement struct {
	dirs       theme.Dirs
	configFile string
	notify     func(string, string) error
	reload     func(*cobra.Command) error
	// export follows a change of the effective theme; nil disables it.
	export func(*cobra.Command, theme.Info)
}

func init() {
	for _, name := range []string{"list", "validate", "current", "apply", "delete"} {
		name := name
		registerThemeSubcommand(func() *cobra.Command {
			return (themeManagement{theme.DefaultDirs(), paths.ConfigFile(), notify.Send, reloadShellTheme, func(cmd *cobra.Command, info theme.Info) { exportActiveTheme(cmd, info, true) }}).command(name)
		})
	}
}

func (m themeManagement) active() (string, error) {
	if value := os.Getenv("SENDA_THEME"); value != "" {
		return value, nil
	}
	values, err := config.Load(m.configFile)
	if err != nil {
		return "", fmt.Errorf("SENDA_THEME: %w", err)
	}
	if value := values["SENDA_THEME"]; value != "" {
		return value, nil
	}
	return theme.DefaultTheme, nil
}

func (m themeManagement) find(name, active string) theme.Info {
	info, ok := theme.Find(m.dirs, name)
	if !ok {
		info = theme.Info{Name: name, Field: "name", Error: "name: theme not found", Colors: map[string]string{}}
	}
	info.Active = info.Name == active
	return info
}

func (m themeManagement) validate(target, active string) theme.Info {
	info := m.inspect(target, active)
	if info.Valid {
		if err := theme.CheckImage(info.Wallpaper); err != nil {
			info.Valid = false
			info.Field = "wallpaper"
			info.Error = "wallpaper: " + err.Error()
		}
	}
	return info
}

func (m themeManagement) inspect(target, active string) theme.Info {
	if !strings.ContainsAny(target, `/\`) && !strings.HasSuffix(target, ".json") {
		return m.find(target, active)
	}
	file, _ := filepath.Abs(target)
	// Use discovery metadata when the path identifies an installed theme.
	for _, info := range theme.Discover(m.dirs) {
		if info.File == file {
			info.Active = info.Name == active
			return info
		}
	}
	info := theme.Info{File: file, Dir: filepath.Dir(file), Colors: map[string]string{}}
	value, err := theme.LoadHeader(file)
	info.Name = value.Name
	info.Active = info.Name == active
	if err == nil {
		info.Valid, info.Colors, info.Wallpaper = true, value.Colors, theme.WallpaperPath(value, info.Dir)
	} else {
		info.Error = err.Error()
		var validation *theme.ValidationError
		if errors.As(err, &validation) {
			info.Field = validation.Field
		}
	}
	return info
}

func (m themeManagement) command(name string) *cobra.Command {
	var jsonOutput, sendNotify, noReload bool
	cmd := &cobra.Command{Use: name, Short: "Manage shell themes", Args: cobra.NoArgs, SilenceUsage: true}
	if name == "validate" {
		cmd.Use += " <name|theme.json>"
		cmd.Args = cobra.ExactArgs(1)
	}
	if name == "apply" || name == "delete" {
		cmd.Use += " <name>"
		cmd.Args = cobra.ExactArgs(1)
	}
	if name == "list" || name == "validate" || name == "current" || name == "apply" {
		cmd.Flags().BoolVar(&jsonOutput, "json", false, "Print JSON")
	}
	if name == "validate" || name == "current" {
		cmd.Flags().BoolVar(&sendNotify, "notify", false, "Notify about invalid themes")
	}
	if name == "apply" || name == "delete" {
		cmd.Flags().BoolVar(&noReload, "no-reload", false, "Skip shell reload")
	}
	cmd.RunE = func(cmd *cobra.Command, args []string) error {
		active, err := m.active()
		if err != nil {
			return err
		}
		switch name {
		case "list":
			infos := theme.Discover(m.dirs)
			for i := range infos {
				infos[i].Active = infos[i].Name == active
			}
			if jsonOutput {
				return writeJSON(cmd, infos)
			}
			table := tabwriter.NewWriter(cmd.OutOrStdout(), 0, 4, 2, ' ', 0)
			fmt.Fprintln(table, "NAME\tBUILTIN\tACTIVE\tVALID\tERROR")
			for _, info := range infos {
				fmt.Fprintf(table, "%s\t%t\t%t\t%t\t%s\n", info.Name, info.Builtin, info.Active, info.Valid, info.Error)
			}
			return table.Flush()
		case "validate":
			info := m.validate(args[0], active)
			if jsonOutput {
				if err := writeJSON(cmd, info); err != nil {
					return err
				}
			}
			if !info.Valid {
				if sendNotify {
					_ = m.notify("Tema no válido", info.Error)
				}
				return errors.New(info.Error)
			}
			if !jsonOutput {
				fmt.Fprintln(cmd.OutOrStdout(), info.Name+": válido")
			}
			return nil
		case "current":
			result, err := m.current(active, sendNotify)
			if err != nil {
				return err
			}
			if jsonOutput {
				return writeJSON(cmd, result)
			}
			fmt.Fprintln(cmd.OutOrStdout(), result.Name)
			if result.Warning != "" {
				fmt.Fprintln(cmd.ErrOrStderr(), result.Warning)
			}
			return nil
		case "apply", "delete":
			info := m.find(args[0], active)
			if name == "apply" {
				if !info.Valid {
					return errors.New(info.Error)
				}
				if err := config.Set(m.configFile, map[string]string{"SENDA_THEME": info.Name}); err != nil {
					return fmt.Errorf("SENDA_THEME: %w", err)
				}
			} else {
				if info.Dir == "" {
					return errors.New(info.Error)
				}
				if info.Builtin {
					return fmt.Errorf("name: cannot delete builtin theme %q", info.Name)
				}
				// Save the fallback before removing the active theme so a config error
				// never leaves the settings pointing at a theme we just deleted.
				if info.Active {
					if err := config.Set(m.configFile, map[string]string{"SENDA_THEME": theme.DefaultTheme}); err != nil {
						return fmt.Errorf("SENDA_THEME: %w", err)
					}
				}
				if err := os.RemoveAll(info.Dir); err != nil {
					return fmt.Errorf("dir: %w", err)
				}
			}
			if !noReload && (name == "apply" || info.Active) {
				_ = m.reload(cmd)
			}
			if m.export != nil && (name == "apply" || info.Active) {
				// Export what current resolves, so SENDA_THEME and the fallback apply.
				effective, _ := m.active()
				if result, err := m.current(effective, false); err == nil {
					m.export(cmd, result.Info)
				}
			}
			if name == "apply" && jsonOutput {
				// Match current's effective selection, including environment priority.
				selected := info.Name
				if value := os.Getenv("SENDA_THEME"); value != "" {
					selected = value
				}
				result, err := m.current(selected, false)
				if err != nil {
					return err
				}
				return writeJSON(cmd, result)
			}
			return nil
		}
		return nil
	}
	return cmd
}

type currentThemeResult struct {
	theme.Info
	Fallback bool   `json:"fallback"`
	Warning  string `json:"warning"`
}

func (m themeManagement) current(active string, sendNotify bool) (currentThemeResult, error) {
	info := m.find(active, active)
	warning := ""
	if !info.Valid {
		warning = fmt.Sprintf("SENDA_THEME: %s: %s", active, info.Error)
		if sendNotify {
			_ = m.notify("Tema no válido", warning)
		}
		info = m.find(theme.DefaultTheme, theme.DefaultTheme)
		if !info.Valid {
			return currentThemeResult{}, fmt.Errorf("%s; %s: %s", warning, theme.DefaultTheme, info.Error)
		}
	}
	return currentThemeResult{info, warning != "", warning}, nil
}
