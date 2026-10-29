package main

import (
	"context"
	"fmt"
	"time"

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
			if _, err := callShellIPC(cmd, "settings", "open"); err != nil {
				return err
			}
			if hyprctl.InSession() {
				focusSettingsWindow(cmd.Context(), hyprctl.New(nil))
			}
			return nil
		},
	}
}

// focusSettingsWindow gives the keyboard to the settings window once it maps.
// Opening it from a shell panel leaves the focus on the window that had it
// before, so closing "the active window" would close that one instead.
func focusSettingsWindow(ctx context.Context, client hyprctl.Client) {
	for attempt := 0; attempt < 20; attempt++ {
		if windows, err := client.Windows(ctx); err == nil {
			for _, window := range windows {
				if window.Title == integration.SettingsWindowTitle {
					_ = client.FocusWindow(ctx, window.Address)
					return
				}
			}
		}
		time.Sleep(50 * time.Millisecond)
	}
}
