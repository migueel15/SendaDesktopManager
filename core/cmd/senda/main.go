package main

import (
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

	rootCmd.Execute()

}
