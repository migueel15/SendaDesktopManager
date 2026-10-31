package main

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
	"github.com/migueel15/SendaDesktopManager/core/internal/wallpaper"
	"github.com/migueel15/SendaDesktopManager/core/internal/wallpaper/adapter/quickshell"
	"github.com/spf13/cobra"
)

func NewWallpaperCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "wallpaper"}
	cmd.AddCommand(newWallpaperSetCmd(), newWallpaperImportCmd(), newWallpaperPickCmd())
	return cmd
}

func newWallpaperSetCmd() *cobra.Command {
	var pos, transitionType, transitionBezier, monitor, resize string
	var duration time.Duration
	var fps int
	cmd := &cobra.Command{
		Use: "set <path>", Short: "Set a wallpaper", Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			kind, err := parseAnimationKind(transitionType)
			if err != nil {
				return err
			}
			mode, err := parseResizeMode(resize)
			if err != nil {
				return err
			}
			bezier, err := parseBezier(transitionBezier)
			if err != nil {
				return err
			}
			if err := validateTransitionDuration(duration); err != nil {
				return err
			}
			animation := wallpaper.Animation{Kind: kind, Duration: duration, FPS: fps, Bezier: bezier}
			if cmd.Flags().Changed("pos") {
				position, err := parsePosition(pos)
				if err != nil {
					return err
				}
				animation.Origin = &position
			}
			path, err := filepath.Abs(args[0])
			if err != nil {
				return err
			}
			if err := theme.CheckImage(path); err != nil {
				return fmt.Errorf("invalid wallpaper: %w", err)
			}
			backend := quickshell.NewBackend(func(target, function string, args ...string) (string, error) {
				return callShellIPCResult(cmd, target, function, args...)
			})
			selectedMonitor := wallpaper.Monitor(monitor)
			return wallpaper.NewService(backend).Set(wallpaper.Wallpaper{Path: path}, wallpaper.SetOptions{
				Monitor: &selectedMonitor, Animation: &animation, Resize: &mode,
			})
		},
	}
	cmd.Flags().StringVar(&pos, "pos", "", "Set transition position x,y in monitor pixels, origin bottom left (default: center)")
	cmd.Flags().DurationVar(&duration, "transition-duration", 3*time.Second, "Set non-negative transition duration")
	cmd.Flags().IntVar(&fps, "transition-fps", 30, "Accepted for compatibility; has no effect")
	cmd.Flags().StringVar(&transitionType, "transition-type", "none", "Set transition type: none|fade|wipe|wave|grow|center|any|outer|random")
	cmd.Flags().StringVar(&transitionBezier, "transition-bezier", ".61,.18,.48,.9", "Set bezier x1,y1,x2,y2; x1 and x2 must be in [0,1]")
	cmd.Flags().StringVar(&monitor, "monitor", "", "Set target monitor (empty: all screens)")
	cmd.Flags().StringVar(&resize, "resize", "crop", "Set resize mode: crop|fit|stretch|none")
	return cmd
}

func newWallpaperPickCmd() *cobra.Command {
	return &cobra.Command{
		Use: "pick", Short: "Open the wallpaper picker", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			_, err := callShellIPC(cmd, "wallpaper", "openPicker")
			return err
		},
	}
}

func newWallpaperImportCmd() *cobra.Command {
	return &cobra.Command{
		Use: "import <path>", Short: "Copy an image to the wallpapers folder and print the copy", Args: cobra.ExactArgs(1), SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			path, err := importWallpaper(args[0], paths.WallpapersDir())
			if err != nil {
				return err
			}
			_, err = fmt.Fprintln(cmd.OutOrStdout(), path)
			return err
		},
	}
}

// importWallpaper copies source into dir, so nothing depends on the original.
// Importing the same content again returns the existing copy.
func importWallpaper(source, dir string) (string, error) {
	if err := theme.CheckImage(source); err != nil {
		return "", fmt.Errorf("invalid wallpaper: %w", err)
	}
	data, err := os.ReadFile(source)
	if err != nil {
		return "", err
	}
	_, format, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return "", fmt.Errorf("invalid wallpaper: %w", err)
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	// The extension follows the content, because the picker filters by extension.
	extension := "." + strings.Replace(format, "jpeg", "jpg", 1)
	stem := strings.TrimSuffix(filepath.Base(source), filepath.Ext(source))
	if strings.HasPrefix(stem, ".") || stem == "" {
		stem = "wallpaper" + stem
	}
	target := ""
	for i := 1; ; i++ {
		target = filepath.Join(dir, stem+extension)
		if i > 1 {
			target = filepath.Join(dir, fmt.Sprintf("%s-%d%s", stem, i, extension))
		}
		existing, err := os.ReadFile(target)
		if os.IsNotExist(err) {
			break
		}
		if err != nil {
			return "", err
		}
		if bytes.Equal(existing, data) {
			return target, nil
		}
	}
	temp, err := os.CreateTemp(dir, ".import-*")
	if err != nil {
		return "", err
	}
	defer os.Remove(temp.Name())
	_, writeErr := temp.Write(data)
	if err := errors.Join(writeErr, temp.Chmod(0o644), temp.Close()); err != nil {
		return "", err
	}
	if err := os.Rename(temp.Name(), target); err != nil {
		return "", err
	}
	return target, nil
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
	return wallpaper.Position{X: x, Y: y}, nil
}

func parseAnimationKind(value string) (wallpaper.AnimationKind, error) {
	switch wallpaper.AnimationKind(value) {
	case wallpaper.AnimationNone, wallpaper.AnimationFade, wallpaper.AnimationWipe, wallpaper.AnimationWave,
		wallpaper.AnimationGrow, wallpaper.AnimationCenter, wallpaper.AnimationAny, wallpaper.AnimationOuter, wallpaper.AnimationRandom:
		return wallpaper.AnimationKind(value), nil
	default:
		return "", fmt.Errorf("invalid transition type %q", value)
	}
}

func parseResizeMode(value string) (wallpaper.ResizeMode, error) {
	switch wallpaper.ResizeMode(value) {
	case wallpaper.ResizeCrop, wallpaper.ResizeFit, wallpaper.ResizeStretch, wallpaper.ResizeNone:
		return wallpaper.ResizeMode(value), nil
	default:
		return "", fmt.Errorf("invalid resize mode %q", value)
	}
}

func parseBezier(value string) ([4]float64, error) {
	var result [4]float64
	parts := strings.Split(value, ",")
	if len(parts) != len(result) {
		return result, fmt.Errorf("invalid bezier %q, expected x1,y1,x2,y2", value)
	}
	for i, part := range parts {
		n, err := strconv.ParseFloat(part, 64)
		if err != nil || math.IsNaN(n) || math.IsInf(n, 0) || (i%2 == 0 && (n < 0 || n > 1)) {
			return result, fmt.Errorf("invalid bezier component %q", part)
		}
		result[i] = n
	}
	return result, nil
}

func validateTransitionDuration(duration time.Duration) error {
	if duration < 0 {
		return fmt.Errorf("transition duration must be non-negative")
	}
	return nil
}
