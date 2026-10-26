package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
	"github.com/spf13/cobra"
)

func init() { registerThemeSubcommand(themeWatchCmd) }

func themeWatchCmd() *cobra.Command {
	var notify bool
	var interval time.Duration
	cmd := &cobra.Command{Use: "watch <name>", Short: "Watch a theme for stable changes", Args: cobra.ExactArgs(1)}
	cmd.Flags().BoolVar(&notify, "notify", false, "Notify about invalid themes")
	cmd.Flags().DurationVar(&interval, "interval", time.Second, "Polling interval")
	cmd.RunE = func(cmd *cobra.Command, args []string) error {
		if !safeThemeName(args[0]) {
			return themeFieldError("name", errors.New("invalid theme name"))
		}
		if interval <= 0 {
			return fmt.Errorf("interval must be positive")
		}
		ctx, stop := signal.NotifyContext(cmd.Context(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		var notifier func(theme.Info)
		if notify {
			notifier = func(info theme.Info) {
				_ = exec.CommandContext(ctx, "notify-send", "Senda theme: "+info.Field, info.Error).Run()
			}
		}
		next := func() error {
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-ticker.C:
				return nil
			}
		}
		return watchTheme(ctx, theme.DefaultDirs(), args[0], activeThemeForSaveWatch(), next, cmd.OutOrStdout(), notifier)
	}
	return cmd
}

type themeFileStamp struct {
	Exists   bool
	Size     int64
	Modified time.Time
	Error    string
}

func stampThemeFile(path string) themeFileStamp {
	stat, err := os.Stat(path)
	if err != nil {
		return themeFileStamp{Error: err.Error()}
	}
	return themeFileStamp{Exists: true, Size: stat.Size(), Modified: stat.ModTime()}
}

type themeWatchStamp struct{ Directory, JSON, Wallpaper themeFileStamp }

func watchTheme(ctx context.Context, dirs theme.Dirs, name, active string, next func() error, output io.Writer, notify func(theme.Info)) error {
	dir := filepath.Join(dirs.User, name)
	builtin := false
	if stat, err := os.Stat(filepath.Join(dirs.Builtin, name)); err == nil && stat.IsDir() {
		dir = filepath.Join(dirs.Builtin, name)
		builtin = true
	}
	dir, err := filepath.Abs(dir)
	if err != nil {
		return err
	}
	file := filepath.Join(dir, "theme.json")
	wallpaper := ""
	read := func() theme.Info {
		info := theme.Info{Name: name, Builtin: builtin, Active: name == active, Dir: dir, File: file, Colors: map[string]string{}}
		value, err := theme.LoadHeader(file)
		if _, statErr := os.Stat(dir); os.IsNotExist(statErr) {
			err = themeFieldError("name", errors.New("theme directory does not exist"))
		}
		if err == nil && !builtin {
			err = theme.ValidateHeader(value, dir, name)
		}
		if err != nil {
			info.Error = err.Error()
			var validation *theme.ValidationError
			if errors.As(err, &validation) {
				info.Field = validation.Field
				if validation.Field == "wallpaper" && value.Wallpaper != "" {
					wallpaper = theme.WallpaperPath(value, dir)
				}
			}
		} else {
			info.Valid = true
			info.Colors = value.Colors
			info.Wallpaper = theme.WallpaperPath(value, dir)
			wallpaper = info.Wallpaper
		}
		return info
	}
	snapshot := func() themeWatchStamp {
		return themeWatchStamp{stampThemeFile(dir), stampThemeFile(file), stampThemeFile(wallpaper)}
	}
	read()
	emitted := snapshot()
	previous := emitted
	for {
		if err := next(); err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		current := snapshot()
		if current != emitted && current == previous {
			info := read()
			emitted = snapshot()
			current = emitted
			if err := json.NewEncoder(output).Encode(info); err != nil {
				return err
			}
			if !info.Valid && notify != nil {
				notify(info)
			}
		}
		previous = current
	}
}
