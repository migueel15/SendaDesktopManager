package main

import (
	"fmt"
	"slices"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

func printStartup(cmd *cobra.Command, entries []integration.StartupEntry, asJSON bool) error {
	if asJSON {
		if entries == nil {
			entries = []integration.StartupEntry{}
		}
		return writeJSON(cmd, entries)
	}
	for _, e := range entries {
		state := "activada"
		if !e.Enabled {
			state = "desactivada"
		}
		fmt.Fprintf(cmd.OutOrStdout(), "%s (%s, %s): %s\n", e.Name, e.Kind, state, e.Target)
	}
	return nil
}

func startupCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "startup", Short: "Aplicaciones, comandos, scripts y archivos que se abren al iniciar Hyprland", SilenceUsage: true}
	var asJSON bool
	// change saves the new list and regenerates the module. A reload does not
	// run anything: the entries only run when Hyprland starts.
	change := func(cmd *cobra.Command, edit func([]integration.StartupEntry) ([]integration.StartupEntry, error)) error {
		s, err := integration.ReadSettings()
		if err != nil {
			return fmt.Errorf("leer ajustes: %w", err)
		}
		if s.Startup, err = edit(s.Startup); err != nil {
			return err
		}
		if err := integration.SaveStartup(paths.ConfigFile(), s.Startup); err != nil {
			return err
		}
		if _, err := applyHyprland(cmd.Context(), s, false); err != nil {
			return err
		}
		return printStartup(cmd, s.Startup, asJSON)
	}
	find := func(entries []integration.StartupEntry, target string) (int, error) {
		i := slices.IndexFunc(entries, func(e integration.StartupEntry) bool { return e.Target == target })
		if i < 0 {
			return i, fmt.Errorf("%q no está en las aplicaciones de inicio", target)
		}
		return i, nil
	}
	show := &cobra.Command{Use: "show", Short: "Mostrar la lista", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		s, err := integration.ReadSettings()
		if err != nil {
			return fmt.Errorf("leer ajustes: %w", err)
		}
		return printStartup(cmd, s.Startup, asJSON)
	}}
	external := &cobra.Command{Use: "external", Short: "Consultar el inicio definido en Hyprland (solo lectura)", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		list, err := integration.ReadUserStartup(cmd.Context(), nil)
		if err != nil {
			return err
		}
		if asJSON {
			return writeJSON(cmd, list)
		}
		if !list.Available {
			fmt.Fprintln(cmd.OutOrStdout(), "La configuración de Hyprland no expone la tabla senda_user_startup.")
			return nil
		}
		return printStartup(cmd, list.Entries, false)
	}}
	var kind, name string
	add := &cobra.Command{Use: "add <comando o ruta>", Short: "Añadir una entrada activada", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		entry, err := integration.NewStartupEntry(kind, name, args[0])
		if err != nil {
			return err
		}
		return change(cmd, func(entries []integration.StartupEntry) ([]integration.StartupEntry, error) {
			if _, err := find(entries, entry.Target); err == nil {
				return nil, fmt.Errorf("%q ya está en las aplicaciones de inicio", entry.Target)
			}
			return append(entries, entry), nil
		})
	}}
	add.Flags().StringVar(&kind, "kind", integration.StartupApp, "app, command, script o file")
	add.Flags().StringVar(&name, "name", "", "Nombre visible; por defecto, el comando o el final de la ruta")
	remove := &cobra.Command{Use: "remove <comando o ruta>", Short: "Eliminar una entrada", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		return change(cmd, func(entries []integration.StartupEntry) ([]integration.StartupEntry, error) {
			i, err := find(entries, args[0])
			if err != nil {
				return nil, err
			}
			return slices.Delete(entries, i, i+1), nil
		})
	}}
	toggle := func(use, short string, enabled bool) *cobra.Command {
		return &cobra.Command{Use: use + " <comando o ruta>", Short: short, Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
			return change(cmd, func(entries []integration.StartupEntry) ([]integration.StartupEntry, error) {
				i, err := find(entries, args[0])
				if err != nil {
					return nil, err
				}
				entries[i].Enabled = enabled
				return entries, nil
			})
		}}
	}
	cmd.PersistentFlags().BoolVar(&asJSON, "json", false, "Mostrar JSON")
	cmd.AddCommand(show, external, add, remove, toggle("enable", "Activar una entrada", true), toggle("disable", "Desactivar una entrada", false))
	return cmd
}
