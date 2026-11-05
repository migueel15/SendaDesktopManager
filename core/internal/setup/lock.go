package setup

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/migueel15/Zenda/core/internal/hyprland/integration"
	"github.com/migueel15/Zenda/core/internal/paths"
)

// ensureLockIntegration writes Zenda's Hyprland module, loads it in Hyprland
// when it is not already loaded and sets up hypridle.
func ensureLockIntegration(ctx context.Context, executable string, in *bufio.Reader, out io.Writer) error {
	s, err := integration.ReadSettings()
	if err != nil {
		return err
	}
	if integration.InSession() {
		link, err := integration.Probe(ctx, nil)
		switch {
		case err != nil:
			fmt.Fprintln(out, "Aviso: no se pudo comprobar la integración con Hyprland:", err)
		case link.Loaded:
			integration.Locate(link)
			fmt.Fprintf(out, "Zenda ya está vinculado a Hyprland (versión %s, %s)\n", link.Version, integration.ModulePath())
		default:
			fmt.Fprintln(out, "Zenda no está vinculado a Hyprland; se añade su módulo")
		}
	}
	chosen := false
	if s.IdleMode == "" {
		s.IdleMode = chooseIdleMode(in, out)
		chosen = true
	}
	if _, err = integration.Render(s, executable); err != nil {
		return err
	}
	if err = integration.CheckTargets(); err != nil {
		return err
	}
	if err = integration.SaveSettings(paths.ConfigFile(), s); err != nil {
		return err
	}
	if err = integration.WriteFiles(s, executable); err != nil {
		return err
	}
	warnings, err := integration.Migrate()
	if err != nil {
		return err
	}
	warning, err := integration.EnsureLinked(ctx, nil)
	if err != nil {
		return err
	}
	if warning != "" {
		warnings = append(warnings, warning)
	}
	fmt.Fprintln(out, "Módulo de Zenda:", integration.ModulePath())
	if s.IdleMode == integration.IdleModeZenda {
		warnings = append(warnings, resolveIdleConflicts(in, out, chosen, integration.InSession())...)
	}
	if s.IdleMode == integration.IdleModeZenda && integration.InSession() {
		if w := integration.ApplyIdle(); w != "" {
			warnings = append(warnings, w)
		}
	}
	for _, w := range warnings {
		fmt.Fprintln(out, "Aviso:", w)
	}
	for _, w := range integration.Inspect(ctx, s, nil).Warnings {
		fmt.Fprintln(out, "Aviso:", w)
	}
	return nil
}

// idleProcesses is replaced in tests, which must not see the real session.
var idleProcesses = integration.IdleProcesses

// userIdleConfig returns the user's own hypridle configuration, if any.
func userIdleConfig() string {
	path := filepath.Join(filepath.Dir(paths.ConfigDir()), "hypr", "hypridle.conf")
	if _, err := os.Stat(path); err == nil {
		return path
	}
	return ""
}

// chooseIdleMode uses Zenda's hypridle configuration when the user has none,
// and otherwise asks. Without an answer the user's configuration is kept.
func chooseIdleMode(in *bufio.Reader, out io.Writer) string {
	own := userIdleConfig()
	external := 0
	if procs, err := idleProcesses("/proc", os.Getuid(), integration.IdlePath()); err == nil {
		external = procs.External
	}
	if own == "" && external == 0 {
		fmt.Fprintln(out, "No hay configuración de hypridle; se usará la de Zenda")
		return integration.IdleModeZenda
	}
	if own != "" {
		fmt.Fprintln(out, "Ya tienes una configuración de hypridle:", own)
	} else {
		fmt.Fprintln(out, "Ya hay un hypridle en ejecución con tu propia configuración")
	}
	fmt.Fprintf(out, "Zenda puede gestionar la inactividad, el bloqueo y la suspensión con su configuración (%s).\n", integration.IdlePath())
	fmt.Fprint(out, "¿Usar la configuración de Zenda en lugar de la tuya? [s/N] ")
	line, _ := in.ReadString('\n')
	if strings.EqualFold(strings.TrimSpace(line), "s") {
		fmt.Fprintln(out, "Se usará la configuración de hypridle de Zenda; Zenda lo inicia al arrancar Hyprland.")
		return integration.IdleModeZenda
	}
	fmt.Fprintln(out, "Se conserva tu configuración de hypridle; puedes cambiarlo con `zenda hyprland set --idle-mode zenda`.")
	return integration.IdleModeUser
}
