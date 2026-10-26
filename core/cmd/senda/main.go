package main

import (
	"os"

	"github.com/spf13/cobra"
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "senda",
		Short: "senda desktop manager",
	}

	rootCmd.AddCommand(NewWallpaperCmd())
	rootCmd.AddCommand(shellCmd)
	rootCmd.AddCommand(streamAudioCmd)
	rootCmd.AddCommand(userCmd)
	rootCmd.AddCommand(brightnessCmd)
	rootCmd.AddCommand(discordCmd())
	rootCmd.AddCommand(calendarCmd())
	rootCmd.AddCommand(configCmd())
	rootCmd.AddCommand(weatherCmd())
	rootCmd.AddCommand(settingsCmd())
	rootCmd.AddCommand(windowCmd())
	rootCmd.AddCommand(notificationsCmd)
	rootCmd.AddCommand(newLauncherCmd())
	rootCmd.AddCommand(themeCmd())
	rootCmd.AddCommand(sttCmd())
	rootCmd.AddCommand(versionCmd())
	rootCmd.AddCommand(updateCmd())
	rootCmd.AddCommand(setupCmd())
	rootCmd.AddCommand(uninstallCmd())

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}

}
