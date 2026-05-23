package main

import (
	"fmt"
	"senda/internal/wallpaper"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

func NewWallpaperCmd(wallpaperService *wallpaper.Service) *cobra.Command {
	wallpaperCmd := &cobra.Command{
		Use: "wallpaper",
	}

	wallpaperCmd.AddCommand(newWallpaperSetCmd(wallpaperService))

	return wallpaperCmd
}

func newWallpaperSetCmd(wallpaperService *wallpaper.Service) *cobra.Command {
	var pos string
	var transitionDuration time.Duration
	var transitionFps int
	var transitionType string
	var transitionBezier string

	wallpaperSetCmd := &cobra.Command{
		Use:   "set",
		Short: "Set a wallpaper",
		Args:  cobra.ExactArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			path := args[0]
			options := wallpaper.SetOptions{}
			animation := wallpaper.Animation{
				Duration: transitionDuration,
				FPS:      transitionFps,
			}

			if pos != "" {
				position, err := parsePosition(pos)
				if err != nil {
				}
				animation.Origin = &position
			}

			if transitionType != "" {
				kind := parseAnimationKind(transitionType)
				animation.Kind = kind
			}

			options.Animation = &animation

			wallpaperService.Set(wallpaper.Wallpaper{Path: path}, options)

		},
	}

	wallpaperSetCmd.Flags().StringVar(
		&pos,
		"pos",
		"",
		`Set initial transition position, e.g. 100,200.
	Origin starts at bottom left corner meaning 0,0`)
	wallpaperSetCmd.Flags().DurationVar(&transitionDuration, "transition-duration", 3*time.Second, "Set transition duration")
	wallpaperSetCmd.Flags().IntVar(&transitionFps, "transition-fps", 30, "Set transition fps")
	wallpaperSetCmd.Flags().StringVar(
		&transitionType,
		"transition-type",
		string(wallpaper.AnimationNone),
		`Set transition type.
		Can be none | fade | wipe | wave | grow | center | any | outer | random`)
	wallpaperSetCmd.Flags().StringVar(&transitionBezier, "transition-bezier", "", "Set transition bezier curve")
	return wallpaperSetCmd
}

func parsePosition(value string) (wallpaper.Position, error) {
	parts := strings.Split(value, ",")
	if len(parts) != 2 {
		return wallpaper.Position{}, fmt.Errorf("invalid position %q, expected x,y", value)
	}

	x, err := strconv.Atoi(parts[0])
	if err != nil {
		return wallpaper.Position{}, fmt.Errorf("invalid x position %q", parts[0])
	}

	y, err := strconv.Atoi(parts[1])
	if err != nil {
		return wallpaper.Position{}, fmt.Errorf("invalid y position %q", parts[1])
	}

	return wallpaper.Position{
		X: x,
		Y: y,
	}, nil
}

func parseAnimationKind(value string) wallpaper.AnimationKind {
	switch strings.ToLower(value) {
	case string(wallpaper.AnimationNone):
		return wallpaper.AnimationNone
	case string(wallpaper.AnimationFade):
		return wallpaper.AnimationFade
	case string(wallpaper.AnimationGrow):
		return wallpaper.AnimationGrow
	case string(wallpaper.AnimationRandom):
		return wallpaper.AnimationRandom
	case string(wallpaper.AnimationWipe):
		return wallpaper.AnimationWipe
	case string(wallpaper.AnimationWave):
		return wallpaper.AnimationWave
	default:
		return wallpaper.AnimationNone
	}
}
