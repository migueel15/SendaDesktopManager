package main

import (
	"fmt"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/spf13/cobra"
)

func settingsCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "settings",
		Short: "Open the Senda settings window in the running shell",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			// Register the placement first: the rule must exist when the
			// window maps. Without it the window still opens, tiled.
			if hyprctl.InSession() {
				if err := hyprctl.New(nil).AddWindowRule(cmd.Context(), integration.SettingsWindowRule()); err != nil {
					fmt.Fprintln(cmd.ErrOrStderr(), "Aviso: no se pudo preparar la ventana flotante:", err)
				}
			}
			_, err := callShellIPC(cmd, "settings", "open")
			return err
		},
	}
}
