package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strconv"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

func integrationExecutable() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("localizar ejecutable: %w", err)
	}
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		return "", fmt.Errorf("resolver ejecutable: %w", err)
	}
	if err := integration.ValidateExecutable(exe); err != nil {
		return "", err
	}
	return exe, nil
}

var hyprlandExecutable = integrationExecutable
var applyIdle = integration.ApplyIdle

func applyHyprland(ctx context.Context, s integration.Settings) (integration.Status, error) {
	exe, err := hyprlandExecutable()
	if err != nil {
		return integration.Status{}, err
	}
	if _, _, err = integration.Render(s, exe); err != nil {
		return integration.Status{}, err
	}
	if err = integration.CheckTargets(); err != nil {
		return integration.Status{}, err
	}
	if err = integration.SaveSettings(paths.ConfigFile(), s); err != nil {
		return integration.Status{}, fmt.Errorf("guardar ajustes: %w", err)
	}
	if err = integration.WriteFiles(s, exe); err != nil {
		return integration.Status{}, err
	}
	warnings, err := integration.Migrate()
	if err != nil {
		return integration.Status{}, fmt.Errorf("migrar integración: %w", err)
	}
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "" {
		if err = binds.Reload(ctx, shortcutRunner); err != nil {
			return integration.Status{}, fmt.Errorf("recargar Hyprland: %w", err)
		}
	}
	idleWarning := applyIdle()
	status := integration.Inspect(ctx, s, shortcutRunner)
	status.Warnings = append(status.Warnings, warnings...)
	if idleWarning != "" {
		status.Warnings = append(status.Warnings, idleWarning)
	}

	return status, nil
}

func printHyprland(cmd *cobra.Command, status integration.Status, asJSON bool) error {
	if asJSON {
		return writeJSON(cmd, status)
	}
	fmt.Fprintf(cmd.OutOrStdout(), "Bloqueo: %s\nDictado: %s\nInactividad: %d s\nDesenfoque: %t\nMódulo: %s (activo: %t)\nHypridle: %s\n", status.LockShortcut, status.DictationShortcut, status.IdleSeconds, status.Blur, status.ModulePath, status.ModuleActive, status.IdleConfigPath)
	for _, warning := range status.Warnings {
		fmt.Fprintln(cmd.OutOrStdout(), "Aviso:", warning)
	}
	return nil
}

func hyprlandCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "hyprland", Short: "Gestionar la integración con Hyprland", SilenceUsage: true}
	show := &cobra.Command{Use: "show", Short: "Mostrar ajustes", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		s, err := integration.ReadSettings()
		if err != nil {
			return fmt.Errorf("leer ajustes: %w", err)
		}
		asJSON, _ := cmd.Flags().GetBool("json")
		return printHyprland(cmd, integration.Inspect(cmd.Context(), s, shortcutRunner), asJSON)
	}}
	show.Flags().Bool("json", false, "Mostrar JSON")
	var lock, dictation, blur string
	var idle int
	var asJSON bool
	set := &cobra.Command{Use: "set", Short: "Cambiar ajustes", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		s, err := integration.ReadSettings()
		if err != nil {
			return fmt.Errorf("leer ajustes: %w", err)
		}
		if cmd.Flags().Changed("lock-shortcut") {
			s.LockShortcut = lock
		}
		if cmd.Flags().Changed("dictation-shortcut") {
			s.DictationShortcut = dictation
		}
		if cmd.Flags().Changed("idle-seconds") {
			s.IdleSeconds = idle
		}
		if cmd.Flags().Changed("blur") {
			if blur != "true" && blur != "false" {
				return fmt.Errorf("blur debe ser true o false")
			}
			s.Blur, err = strconv.ParseBool(blur)
			if err != nil {
				return fmt.Errorf("blur inválido: %w", err)
			}
		}
		s.LockShortcut, err = binds.NormalizeShortcut(s.LockShortcut)
		if err != nil {
			return fmt.Errorf("atajo de bloqueo: %w", err)
		}
		s.DictationShortcut, err = binds.NormalizeShortcut(s.DictationShortcut)
		if err != nil {
			return fmt.Errorf("atajo de dictado: %w", err)
		}
		status, err := applyHyprland(cmd.Context(), s)
		if err != nil {
			return err
		}
		return printHyprland(cmd, status, asJSON)
	}}
	set.Flags().StringVar(&lock, "lock-shortcut", "", "Atajo de bloqueo")
	set.Flags().StringVar(&dictation, "dictation-shortcut", "", "Atajo de dictado")
	set.Flags().IntVar(&idle, "idle-seconds", 0, "Segundos de inactividad (0 desactiva)")
	set.Flags().StringVar(&blur, "blur", "", "Desenfoque: true o false")
	set.Flags().BoolVar(&asJSON, "json", false, "Mostrar JSON")
	for _, sub := range []*cobra.Command{show, set} {
		sub.SetFlagErrorFunc(func(_ *cobra.Command, err error) error { return fmt.Errorf("opción inválida: %w", err) })
		sub.Args = func(_ *cobra.Command, args []string) error {
			if len(args) != 0 {
				return fmt.Errorf("este comando no admite argumentos posicionales")
			}
			return nil
		}
	}
	cmd.AddCommand(show, set)
	return cmd
}
