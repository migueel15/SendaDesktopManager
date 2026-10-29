package main

import (
	"os"
	"os/exec"

	"github.com/migueel15/SendaDesktopManager/core/internal/setup"
	"github.com/spf13/cobra"
)

// setupCmd returns the command that performs the first-time installation of
// Senda's dependencies, configuration and Quickshell files.
func setupCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "setup",
		Short: "install Senda's dependencies and Quickshell files on this system",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return setup.Run(cmd.Context(), setup.Options{
				In:              cmd.InOrStdin(),
				Out:             cmd.OutOrStdout(),
				Getenv:          os.Getenv,
				Euid:            os.Geteuid(),
				OSReleasePath:   "/etc/os-release",
				LookPath:        exec.LookPath,
				Pacman:          setup.SystemPacman{},
				Executable:      os.Executable,
				StartShell:      setup.StartShell,
				ReleasesURL:     releasesURL,
				ReleaseDownload: releaseDownload,
			})
		},
	}
}
