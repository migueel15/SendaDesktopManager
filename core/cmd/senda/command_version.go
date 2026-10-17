package main

import (
	"fmt"

	"github.com/migueel15/SendaDesktopManager/core/internal/version"
	"github.com/spf13/cobra"
)

// versionCmd returns the command that prints the senda build version.
func versionCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "print the senda version",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Fprintf(cmd.OutOrStdout(), "senda %s\n", version.Version)
		},
	}
}
