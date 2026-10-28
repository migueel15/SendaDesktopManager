package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

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
var stopExternalIdle = integration.StopExternalIdle

func applyHyprland(ctx context.Context, s integration.Settings, idleChanged bool) (integration.Status, error) {
	exe, err := hyprlandExecutable()
	if err != nil {
		return integration.Status{}, err
	}
	if s.IdleMode == "" {
		// Without a recorded choice, never take over the user's hypridle.
		s.IdleMode = integration.IdleModeUser
	}
	if integration.InSession() {
		if link, err := integration.Probe(ctx, shortcutRunner); err == nil {
			integration.Locate(link)
		}
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
	linkWarning, err := integration.EnsureLinked(ctx, shortcutRunner)
	if err != nil {
		return integration.Status{}, fmt.Errorf("vincular con Hyprland: %w", err)
	}
	if linkWarning != "" {
		warnings = append(warnings, linkWarning)
	}
	if integration.InSession() {
		if err = binds.Reload(ctx, shortcutRunner); err != nil {
			return integration.Status{}, fmt.Errorf("recargar Hyprland: %w", err)
		}
	}
	if s.IdleMode == integration.IdleModeSenda {
		if idleChanged {
			if w := stopExternalIdle(); w != "" {
				warnings = append(warnings, w)
			}
		}
		if w := applyIdle(); w != "" {
			warnings = append(warnings, w)
		}
	}
	status := integration.Inspect(ctx, s, shortcutRunner)
	status.Warnings = append(status.Warnings, warnings...)

	return status, nil
}

func printHyprland(cmd *cobra.Command, status integration.Status, asJSON bool) error {
	if asJSON {
		return writeJSON(cmd, status)
	}
	fmt.Fprintf(cmd.OutOrStdout(), "Bloqueo: %s\nDictado: %s\nCaptura: %s\nInactividad: %d s\nDesenfoque: %t\nMódulo: %s (activo: %t)\nHypridle: %s (modo: %s)\n", status.LockShortcut, status.DictationShortcut, status.ScreenshotShortcut, status.IdleSeconds, status.Blur, status.ModulePath, status.ModuleActive, status.IdleConfigPath, status.IdleMode)
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
	var lock, dictation, screenshot, blur, idleMode string
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
		if cmd.Flags().Changed("screenshot-shortcut") {
			s.ScreenshotShortcut = screenshot
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
		idleChanged := false
		if cmd.Flags().Changed("idle-mode") {
			if idleMode != integration.IdleModeSenda && idleMode != integration.IdleModeUser {
				return fmt.Errorf("idle-mode debe ser senda o user")
			}
			idleChanged = idleMode != s.IdleMode
			s.IdleMode = idleMode
		}
		s.LockShortcut, err = binds.NormalizeShortcut(s.LockShortcut)
		if err != nil {
			return fmt.Errorf("atajo de bloqueo: %w", err)
		}
		s.DictationShortcut, err = binds.NormalizeShortcut(s.DictationShortcut)
		if err != nil {
			return fmt.Errorf("atajo de dictado: %w", err)
		}
		status, err := applyHyprland(cmd.Context(), s, idleChanged)
		if err != nil {
			return err
		}
		return printHyprland(cmd, status, asJSON)
	}}
	set.Flags().StringVar(&screenshot, "screenshot-shortcut", "", "Atajo de captura")
	set.Flags().StringVar(&lock, "lock-shortcut", "", "Atajo de bloqueo")
	set.Flags().StringVar(&dictation, "dictation-shortcut", "", "Atajo de dictado")
	set.Flags().IntVar(&idle, "idle-seconds", 0, "Segundos de inactividad (0 desactiva)")
	set.Flags().StringVar(&blur, "blur", "", "Desenfoque: true o false")
	set.Flags().StringVar(&idleMode, "idle-mode", "", "hypridle: senda (configuración de Senda) o user (la tuya)")
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
	cmd.AddCommand(show, set, captureCmd(), checkCmd())
	return cmd
}

// captureCmd enters or leaves the empty submap used while recording a shortcut.
func captureCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "capture", Short: "Modo de grabación de atajos", SilenceUsage: true}
	start := &cobra.Command{Use: "start", SilenceUsage: true, Short: "Desactivar los atajos de Hyprland para grabar uno", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		return integration.StartCapture(cmd.Context(), shortcutRunner)
	}}
	stop := &cobra.Command{Use: "stop", SilenceUsage: true, Short: "Restaurar los atajos de Hyprland", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		return integration.StopCapture(cmd.Context(), shortcutRunner)
	}}
	cmd.AddCommand(start, stop)
	return cmd
}

type shortcutCheck struct {
	Shortcut  string   `json:"shortcut"`
	Conflicts []string `json:"conflicts"`
}

// checkCmd validates a shortcut and lists the Hyprland binds that already use
// it, ignoring the Senda bind it would replace.
func checkCmd() *cobra.Command {
	var shortcut, target string
	cmd := &cobra.Command{Use: "check", SilenceUsage: true, Short: "Comprobar si un atajo está libre", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		if target != "lock" && target != "dictation" && target != "screenshot" {
			return fmt.Errorf("--for debe ser lock, dictation o screenshot")
		}
		normalized, err := binds.NormalizeShortcut(shortcut)
		if err != nil {
			return err
		}
		s, err := integration.ReadSettings()
		if err != nil {
			return fmt.Errorf("leer ajustes: %w", err)
		}
		result := shortcutCheck{Shortcut: normalized, Conflicts: []string{}}
		for _, pair := range []struct{ target, shortcut, label string }{{"lock", s.LockShortcut, "bloqueo"}, {"dictation", s.DictationShortcut, "dictado"}, {"screenshot", s.ScreenshotShortcut, "captura"}} {
			if pair.target == target {
				continue
			}
			if o, err := binds.NormalizeShortcut(pair.shortcut); err == nil && sameShortcut(o, normalized) {
				result.Conflicts = append(result.Conflicts, "Senda: "+pair.label)
			}
		}
		if integration.InSession() {
			conflicts, err := binds.Conflicts(cmd.Context(), shortcutRunner, normalized)
			if err != nil {
				return err
			}
			for _, c := range conflicts {
				if c == "Senda lock" || c == "Senda screenshot" || c == "Senda: cancelar grabación de atajo" {
					continue
				}
				result.Conflicts = append(result.Conflicts, c)
			}
		}
		return writeJSON(cmd, result)
	}}
	cmd.Flags().StringVar(&shortcut, "shortcut", "", "Atajo a comprobar")
	cmd.Flags().StringVar(&target, "for", "", "Atajo de Senda que se cambiaría: lock, dictation o screenshot")
	return cmd
}

// sameShortcut ignores modifier order and key case.
func sameShortcut(a, b string) bool {
	norm := func(s string) string {
		parts := strings.Split(s, " + ")
		mods := append([]string(nil), parts[:len(parts)-1]...)
		sort.Strings(mods)
		return strings.Join(mods, "+") + "+" + strings.ToLower(parts[len(parts)-1])
	}
	return norm(a) == norm(b)
}
