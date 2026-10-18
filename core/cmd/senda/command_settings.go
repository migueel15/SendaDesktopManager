package main

import (
	"github.com/spf13/cobra"
)

func settingsCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "settings",
		Short: "Open the Senda settings panel in the running shell",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			_, err := callShellIPC(cmd, "settings", "open")
			return err
		},
	}
}
