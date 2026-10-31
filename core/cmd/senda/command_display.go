package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

// persistDisplays saves rules and regenerates the module, so they survive
// restarts. It returns false when the module is not loaded and a full apply has
// already handled the change.
func persistDisplays(ctx context.Context, rules, previous []integration.DisplayRule) (bool, error) {
	if err := integration.StoreDisplays(paths.ConfigFile(), rules, previous); err != nil {
		return false, fmt.Errorf("guardar pantallas: %w", err)
	}
	s, err := integration.ReadSettings()
	if err != nil {
		return false, fmt.Errorf("leer ajustes: %w", err)
	}
	loaded := false
	if integration.InSession() {
		if link, err := integration.Probe(ctx, shortcutRunner); err == nil {
			integration.Locate(link)
			loaded = link.Current()
		}
	}
	if !loaded {
		_, err = applyHyprland(ctx, s, false)
		return false, err
	}
	exe, err := hyprlandExecutable()
	if err != nil {
		return false, err
	}
	if s.IdleMode == "" {
		s.IdleMode = integration.IdleModeUser
	}
	return true, integration.WriteFiles(s, exe)
}

// commitDisplays persists rules and applies only what changed: a reload would
// modeset every monitor and wipe what plugins adjust at runtime.
func commitDisplays(ctx context.Context, rules, previous []integration.DisplayRule) error {
	apply, err := persistDisplays(ctx, rules, previous)
	if err != nil || !apply {
		return err
	}
	s, err := integration.ReadSettings()
	if err != nil {
		return err
	}
	return integration.ApplyDisplayChanges(ctx, shortcutRunner, previous, s.Displays)
}

func displayConfirmPath() string { return filepath.Join(paths.StateDir(), "display-confirm") }

// applyDisplays tries changes in the session without saving anything. The
// timer runs here and not in the interface, and termination signals are
// ignored, so a shell that dies or a black screen still ends in a revert.
func applyDisplays(cmd *cobra.Command, changesJSON string, seconds int) error {
	ctx := context.Background()
	for _, sig := range []os.Signal{syscall.SIGTERM, syscall.SIGINT, syscall.SIGHUP} {
		signal.Ignore(sig)
	}
	var changes []integration.DisplayEdit
	if err := json.Unmarshal([]byte(changesJSON), &changes); err != nil {
		return fmt.Errorf("cambios inválidos: %w", err)
	}
	rules, _, err := integration.StoredDisplays(paths.ConfigFile())
	if err != nil {
		return fmt.Errorf("leer pantallas: %w", err)
	}
	next := rules
	for _, edit := range changes {
		if next, err = integration.ChangeDisplay(ctx, shortcutRunner, next, edit.Name, edit.DisplayChange); err != nil {
			return err
		}
	}
	if next, err = integration.NormalizeLayout(ctx, shortcutRunner, next); err != nil {
		return err
	}
	restore, err := integration.ApplyTrial(ctx, shortcutRunner, rules, next)
	if err != nil {
		return err
	}
	path := displayConfirmPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		restore()
		return err
	}
	if err := os.WriteFile(path, []byte("pending"), 0o600); err != nil {
		restore()
		return err
	}
	defer os.Remove(path)
	fmt.Fprintln(cmd.OutOrStdout(), "pending")
	deadline := time.Now().Add(time.Duration(seconds) * time.Second)
	for time.Now().Before(deadline) {
		data, _ := os.ReadFile(path)
		switch string(data) {
		case "keep":
			if _, err := persistDisplays(ctx, next, rules); err != nil {
				return err
			}
			fmt.Fprintln(cmd.OutOrStdout(), "kept")
			return nil
		case "revert":
			deadline = time.Now()
		}
		time.Sleep(100 * time.Millisecond)
	}
	if err := restore(); err != nil {
		return fmt.Errorf("revertir pantallas: %w", err)
	}
	fmt.Fprintln(cmd.OutOrStdout(), "reverted")
	return nil
}

func answerDisplays(answer string) error {
	path := displayConfirmPath()
	if _, err := os.Stat(path); err != nil {
		return fmt.Errorf("no hay cambios de pantalla pendientes")
	}
	return os.WriteFile(path, []byte(answer), 0o600)
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
	var changes string
	var seconds int
	apply := &cobra.Command{Use: "apply", Short: "Probar varios cambios y revertirlos si no se confirman", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		return applyDisplays(cmd, changes, seconds)
	}}
	apply.Flags().StringVar(&changes, "changes", "", `Cambios en JSON: [{"name":"DP-1","mode":"1920x1080@60","scale":1.5}]`)
	apply.Flags().IntVar(&seconds, "confirm", 15, "Segundos para confirmar antes de revertir")
	confirm := &cobra.Command{Use: "confirm", Short: "Mantener los cambios en prueba", Args: cobra.NoArgs, RunE: func(*cobra.Command, []string) error {
		return answerDisplays("keep")
	}}
	cancel := &cobra.Command{Use: "cancel", Short: "Revertir los cambios en prueba", Args: cobra.NoArgs, RunE: func(*cobra.Command, []string) error {
		return answerDisplays("revert")
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
	cmd.AddCommand(show, set, reset, adopt, undo, apply, confirm, cancel, sync, watch)
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
	current, err := integration.ReadGenerated()
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
	wanted, err := integration.Render(s, exe)
	if err != nil {
		return err
	}
	if integration.DisplayLines(current) == integration.DisplayLines(wanted.Text()) {
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
