package main

import (
	"senda/internal/wallpaper"
	"senda/internal/wallpaper/adapter/awww"

	"github.com/spf13/cobra"
)

func main() {
	// pos := os.Args[1]
	// image := os.Args[2]
	// cmd := exec.Command("awww", "img", "--transition-bezier", ".61,.18,.48,.9", "--transition-duration", "1", "--transition-fps", "144", "--transition-type", "grow", "--transition-pos", pos, image)
	//
	// cmd.Run()
	//
	// cmd = exec.Command("notify-send", "Wallpaper updated!")
	// cmd.Run()

	backend := awww.NewBackend()
	service := wallpaper.NewService(backend)

	rootCmd := &cobra.Command{
		Use:   "senda",
		Short: "senda desktop manager",
	}

	rootCmd.AddCommand(NewWallpaperCmd(service))

	rootCmd.Execute()

}
