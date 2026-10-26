package main

import "github.com/spf13/cobra"

func newLauncherCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "launcher", Short: "Application launcher commands"}
	var screen string
	toggle := &cobra.Command{
		Use:   "toggle",
		Short: "Open or close the application launcher",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if screen != "" {
				_, err := callShellIPC(cmd, "launcher", "toggleOnScreen", screen)
				return err
			}
			_, err := callShellIPC(cmd, "launcher", "toggle")
			return err
		},
	}
	toggle.Flags().StringVar(&screen, "screen", "", "Monitor name (defaults to the focused monitor)")
	cmd.AddCommand(toggle)
	return cmd
}
