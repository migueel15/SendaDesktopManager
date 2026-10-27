package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/discordbridge"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/service"
	"github.com/spf13/cobra"
)

// uninstallCmd returns the command that removes senda.service, the binary
// and every Senda directory. Packages installed with pacman are kept.
func uninstallCmd() *cobra.Command {
	var yes bool
	cmd := &cobra.Command{
		Use:   "uninstall",
		Short: "remove senda, its service, data, configuration and state",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runUninstall(cmd, yes)
		},
	}
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "do not ask for confirmation")
	return cmd
}

func runUninstall(cmd *cobra.Command, yes bool) error {
	return runUninstallWith(cmd, yes, uninstallDeps{
		getenv: os.Getenv, executable: resolveExecutable, removeService: service.Remove,
		cancelSession: func(ctx context.Context) error {
			return exec.CommandContext(ctx, "qs", "ipc", "call", "stt", "cancel").Run()
		},
		closeShell: closeShell,
		stopBridge: func() error { return discordbridge.Stop(discordbridge.SocketPath(), 3*time.Second) },
		removeIntegration: func() ([]string, error) {
			idleWarning := integration.StopIdle()
			warnings, err := integration.RemoveManaged()
			if idleWarning != "" {
				warnings = append(warnings, idleWarning)
			}
			return warnings, err
		},
		removeAll: os.RemoveAll,
	})
}

type uninstallDeps struct {
	getenv            func(string) string
	executable        func() (string, error)
	removeService     func() error
	cancelSession     func(context.Context) error
	closeShell        func() bool
	stopBridge        func() error
	removeIntegration func() ([]string, error)
	removeAll         func(string) error
}

func runUninstallWith(cmd *cobra.Command, yes bool, deps uninstallDeps) error {
	out := cmd.OutOrStdout()

	// With SENDA_HOME the data directory is a development checkout.
	if deps.getenv("SENDA_HOME") != "" {
		return errors.New("SENDA_HOME está definido para desarrollo; no se desinstala nada")
	}

	exe, err := deps.executable()
	if err != nil {
		return err
	}
	targets := []string{paths.DataDir(), paths.ConfigDir(), paths.StateDir(), exe}

	fmt.Fprintln(out, "Se eliminará el servicio senda.service y:")
	for _, target := range targets {
		fmt.Fprintln(out, "  "+target)
	}
	fmt.Fprintln(out, "Los paquetes instalados con pacman no se eliminan.")
	if !yes {
		fmt.Fprint(out, "¿Continuar? [s/N] ")
		line, _ := bufio.NewReader(cmd.InOrStdin()).ReadString('\n')
		if !strings.EqualFold(strings.TrimSpace(line), "s") {
			fmt.Fprintln(out, "Cancelado")
			return nil
		}
	}

	if err := deps.cancelSession(cmd.Context()); err != nil {
		fmt.Fprintln(cmd.ErrOrStderr(), "aviso: no se pudo cancelar el dictado:", err)
	}
	warnings, err := deps.removeIntegration()
	if err != nil {
		return fmt.Errorf("retirar integración de Hyprland: %w", err)
	}
	for _, warning := range warnings {
		fmt.Fprintln(cmd.ErrOrStderr(), "aviso:", warning)
	}

	if err := deps.removeService(); err != nil {
		return fmt.Errorf("eliminar senda.service: %w", err)
	}
	// Without the service, stop an instance started by hand.
	deps.closeShell()
	if err := deps.stopBridge(); err != nil {
		fmt.Fprintln(cmd.ErrOrStderr(), "aviso:", err)
	}

	for _, target := range targets {
		if target == paths.ConfigDir() && len(warnings) > 0 {
			fmt.Fprintln(cmd.ErrOrStderr(), "aviso: se conserva el directorio de configuración por seguridad:", target)
			continue
		}
		if err := deps.removeAll(target); err != nil {
			return fmt.Errorf("eliminar %s: %w", target, err)
		}
	}
	fmt.Fprintln(out, "Senda desinstalada")
	return nil
}
