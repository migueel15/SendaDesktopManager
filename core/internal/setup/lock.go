package setup

import (
	"context"
	"fmt"
	"io"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
)

func ensureLockIntegration(_ string, executable string, out io.Writer) error {
	s, err := integration.ReadSettings()
	if err != nil {
		return err
	}
	if _, _, err = integration.Render(s, executable); err != nil {
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
	for _, w := range warnings {
		fmt.Fprintln(out, "Aviso:", w)
	}
	fmt.Fprintln(out, "Módulo de Senda:", integration.ModulePath())
	fmt.Fprintln(out, "Para activar el módulo, añade a hyprland.lua:", integration.RequireLine)
	fmt.Fprintf(out, "Inicia una única instancia de hypridle con: hypridle -c %q\n", integration.IdlePath())
	fmt.Fprintln(out, "Si ya hay otra instancia, integra su configuración antes de sustituirla.")
	for _, warning := range integration.Inspect(context.Background(), s, nil).Warnings {
		fmt.Fprintln(out, "Aviso:", warning)
	}
	return nil
}
