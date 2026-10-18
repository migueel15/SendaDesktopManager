package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/discordbridge"
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
	out := cmd.OutOrStdout()

	// With SENDA_HOME the data directory is a development checkout.
	if os.Getenv("SENDA_HOME") != "" {
		return errors.New("SENDA_HOME está definido para desarrollo; no se desinstala nada")
	}

	exe, err := resolveExecutable()
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

	if err := service.Remove(); err != nil {
		return fmt.Errorf("eliminar senda.service: %w", err)
	}
	// Without the service, stop an instance started by hand.
	closeShell()
	if err := discordbridge.Stop(discordbridge.SocketPath(), 3*time.Second); err != nil {
		fmt.Fprintln(cmd.ErrOrStderr(), "aviso:", err)
	}

	for _, target := range targets {
		if err := os.RemoveAll(target); err != nil {
			return fmt.Errorf("eliminar %s: %w", target, err)
		}
	}
	fmt.Fprintln(out, "Senda desinstalada")
	return nil
}
