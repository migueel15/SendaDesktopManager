package main

import (
	"fmt"

	"github.com/migueel15/Zenda/core/internal/version"
	"github.com/spf13/cobra"
)

// versionCmd returns the command that prints the zenda build version.
func versionCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "print the zenda version",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Fprintf(cmd.OutOrStdout(), "zenda %s\n", version.Version)
		},
	}
}
