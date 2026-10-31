package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

// commitDisplays saves rules, regenerates the module so they survive restarts,
// and applies only what changed: a reload would modeset every monitor and wipe
// what plugins adjust at runtime. Only a removed rule needs one, since nothing
// else tells Hyprland to forget it.
func commitDisplays(ctx context.Context, rules, previous []integration.DisplayRule) error {
	if err := integration.StoreDisplays(paths.ConfigFile(), rules, previous); err != nil {
		return fmt.Errorf("guardar pantallas: %w", err)
	}
	s, err := integration.ReadSettings()
	if err != nil {
		return fmt.Errorf("leer ajustes: %w", err)
	}
	if !integration.InSession() {
		_, err = applyHyprland(ctx, s, false)
		return err
	}
	if link, err := integration.Probe(ctx, shortcutRunner); err == nil {
		integration.Locate(link)
		if !link.Loaded {
			_, err = applyHyprland(ctx, s, false)
			return err
		}
	}
	exe, err := hyprlandExecutable()
	if err != nil {
		return err
	}
	if s.IdleMode == "" {
		s.IdleMode = integration.IdleModeUser
	}
	if err := integration.WriteFiles(s, exe); err != nil {
		return err
	}
	return integration.ApplyDisplayChanges(ctx, shortcutRunner, previous, s.Displays)
}

func printDisplays(cmd *cobra.Command, asJSON bool) error {
	rules, previous, err := integration.StoredDisplays(paths.ConfigFile())
	if err != nil {
		return fmt.Errorf("leer pantallas: %w", err)
	}
	state, err := integration.InspectDisplays(cmd.Context(), shortcutRunner, rules, previous != nil)
	if err != nil {
		return err
	}
	if asJSON {
		return writeJSON(cmd, state)
	}
	for _, d := range state.Displays {
		line := fmt.Sprintf("%s: %dx%d@%.2f en %dx%d, escala %g, rotación %d", d.Name, d.Width, d.Height, d.RefreshRate, d.X, d.Y, d.Scale, d.Transform)
		if !d.Enabled {
			line += ", apagada"
		}
		if d.MirrorOf != "" && d.MirrorOf != "none" {
			line += ", duplica " + d.MirrorOf
		}
		if d.ManagedBy == "user" {
			line += ", gestionada por tu configuración (" + d.Source + ")"
		}
		fmt.Fprintln(cmd.OutOrStdout(), line)
	}
	return nil
}

func displayCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "display", Short: "Configurar las pantallas", SilenceUsage: true}
	var showJSON bool
	show := &cobra.Command{Use: "show", Short: "Mostrar las pantallas", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		return printDisplays(cmd, showJSON)
	}}
	show.Flags().BoolVar(&showJSON, "json", false, "Mostrar JSON")

	var change integration.DisplayChange
	var scale float64
	var transform int
	var mirror string
	var enabled bool
	set := &cobra.Command{Use: "set PANTALLA", Short: "Cambiar una pantalla y aplicarlo en vivo", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		flags := cmd.Flags()
		if flags.Changed("scale") {
			change.Scale = &scale
		}
		if flags.Changed("transform") {
			change.Transform = &transform
		}
		if flags.Changed("mirror") {
			change.Mirror = &mirror
		}
		if flags.Changed("enabled") {
			change.Enabled = &enabled
		}
		rules, _, err := integration.StoredDisplays(paths.ConfigFile())
		if err != nil {
			return fmt.Errorf("leer pantallas: %w", err)
		}
		next, err := integration.ChangeDisplay(cmd.Context(), shortcutRunner, rules, args[0], change)
		if err != nil {
			return err
		}
		return commitDisplays(cmd.Context(), next, rules)
	}}
	set.Flags().StringVar(&change.Mode, "mode", "", "Modo, por ejemplo 1920x1080@60")
	set.Flags().StringVar(&change.Position, "position", "", "Posición, por ejemplo 1920x0")
	set.Flags().Float64Var(&scale, "scale", 1, "Escala")
	set.Flags().IntVar(&transform, "transform", 0, "Rotación: 0 normal, 1 90°, 2 180°, 3 270°")
	set.Flags().StringVar(&mirror, "mirror", "", "Pantalla que se duplica, o none para dejar de duplicar")
	set.Flags().BoolVar(&enabled, "enabled", true, "Encender o apagar la pantalla")

	reset := &cobra.Command{Use: "reset PANTALLA", Short: "Devolver una pantalla a la configuración de Hyprland", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		rules, _, err := integration.StoredDisplays(paths.ConfigFile())
		if err != nil {
			return fmt.Errorf("leer pantallas: %w", err)
		}
		next, err := integration.ResetDisplay(cmd.Context(), shortcutRunner, rules, args[0])
		if err != nil {
			return err
		}
		return commitDisplays(cmd.Context(), next, rules)
	}}
	adopt := &cobra.Command{Use: "adopt", Short: "Guardar el estado actual de las pantallas en Senda", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		rules, _, err := integration.StoredDisplays(paths.ConfigFile())
		if err != nil {
			return fmt.Errorf("leer pantallas: %w", err)
		}
		next, err := integration.AdoptDisplays(cmd.Context(), shortcutRunner, rules)
		if err != nil {
			return err
		}
		return commitDisplays(cmd.Context(), next, rules)
	}}
	undo := &cobra.Command{Use: "undo", Short: "Deshacer el último cambio de pantallas", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		rules, previous, err := integration.StoredDisplays(paths.ConfigFile())
		if err != nil {
			return fmt.Errorf("leer pantallas: %w", err)
		}
		if previous == nil {
			return fmt.Errorf("no hay ningún cambio que deshacer")
		}
		return commitDisplays(cmd.Context(), previous, rules)
	}}
	sync := &cobra.Command{Use: "sync", Short: "Regenerar el módulo si tu configuración de monitores ha cambiado", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		return syncDisplays(cmd.Context())
	}}
	watch := &cobra.Command{Use: "watch", Hidden: true, Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		report := func() {
			if err := syncDisplays(cmd.Context()); err != nil {
				fmt.Fprintln(os.Stderr, "display sync:", err)
			}
		}
		// Two watchers with different views of the rules would rewrite the
		// module and reload in turns forever, so only one may run.
		unlock, err := integration.LockDisplayWatch()
		if err != nil {
			return nil
		}
		defer unlock()
		report()
		hyprctl.WatchEvents(cmd.Context(), func(name, _ string) {
			if name == hyprctl.EventConfigReloaded {
				report()
			}
		})
		return nil
	}}
	cmd.AddCommand(show, set, reset, adopt, undo, sync, watch)
	return cmd
}

const displaySyncInterval = time.Minute

var lastDisplaySync time.Time

// syncDisplays stops a generated rule from beating a monitor the user has just
// defined: the module loads last, so it must never keep a stale rule. A module
// that does not exist yet is left alone.
func syncDisplays(ctx context.Context) error {
	if integration.InSession() {
		if link, err := integration.Probe(ctx, shortcutRunner); err == nil {
			integration.Locate(link)
		}
	}
	current, err := os.ReadFile(integration.ModulePath())
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	s, err := integration.ReadSettings()
	if err != nil {
		return err
	}
	exe, err := hyprlandExecutable()
	if err != nil {
		return err
	}
	wanted, _, err := integration.Render(s, exe)
	if err != nil {
		return err
	}
	if integration.DisplayLines(current) == integration.DisplayLines(wanted) {
		return nil
	}
	// At most one automatic reload per window, whatever else rewrites the module.
	if time.Since(lastDisplaySync) < displaySyncInterval {
		return nil
	}
	lastDisplaySync = time.Now()
	_, err = applyHyprland(ctx, s, false)
	return err
}
