package main

import (
	"os"

	"github.com/migueel15/SendaDesktopManager/core/internal/wallpaper"
	"github.com/migueel15/SendaDesktopManager/core/internal/wallpaper/adapter/awww"
	"github.com/spf13/cobra"
)

func main() {
	backend := awww.NewBackend()
	service := wallpaper.NewService(backend)

	rootCmd := &cobra.Command{
		Use:   "senda",
		Short: "senda desktop manager",
	}

	rootCmd.AddCommand(NewWallpaperCmd(service))
	rootCmd.AddCommand(shellCmd)
	rootCmd.AddCommand(streamAudioCmd)
	rootCmd.AddCommand(userCmd)
	rootCmd.AddCommand(brightnessCmd)
	rootCmd.AddCommand(discordCmd())
	rootCmd.AddCommand(calendarCmd())
	rootCmd.AddCommand(configCmd())
	rootCmd.AddCommand(windowCmd())
	rootCmd.AddCommand(notificationsCmd)
	rootCmd.AddCommand(versionCmd())
	rootCmd.AddCommand(updateCmd())
	rootCmd.AddCommand(setupCmd())

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}

}
