package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"io"
	"os"
	"path/filepath"
	"regexp"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
	"github.com/spf13/cobra"
)

func init() { registerThemeSubcommand(themeSaveCmd) }

type themeSaveInput struct {
	Name      string            `json:"name"`
	Colors    map[string]string `json:"colors"`
	Wallpaper string            `json:"wallpaper"`
	Original  string            `json:"original"`
}

type themeSaveOptions struct {
	dirs               theme.Dirs
	configFile, active string
	rename             func(string, string) error
}

func themeSaveCmd() *cobra.Command {
	var asJSON, noReload bool
	cmd := &cobra.Command{Use: "save", Short: "Save a user theme from JSON on stdin", Args: cobra.NoArgs}
	cmd.Flags().BoolVar(&asJSON, "json", false, "Output JSON")
	cmd.Flags().BoolVar(&noReload, "no-reload", false, "Do not reload the active theme")
	cmd.RunE = func(cmd *cobra.Command, _ []string) error {
		var input themeSaveInput
		decoder := json.NewDecoder(cmd.InOrStdin())
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&input); err != nil {
			return themeFieldError("json", err)
		}
		if err := decoder.Decode(new(any)); err != io.EOF {
			return themeFieldError("json", fmt.Errorf("expected a single JSON object"))
		}
		info, err := saveUserTheme(input, themeSaveOptions{theme.DefaultDirs(), paths.ConfigFile(), activeThemeForSaveWatch(), os.Rename})
		if err != nil {
			return err
		}
		if asJSON {
			err = json.NewEncoder(cmd.OutOrStdout()).Encode(info)
		} else {
			_, err = fmt.Fprintln(cmd.OutOrStdout(), info.Name)
		}
		if err != nil {
			return err
		}
		if info.Active {
			exportActiveTheme(cmd, info, true)
		}
		if info.Active && !noReload {
			return reloadShellTheme(cmd)
		}
		return nil
	}
	return cmd
}

func activeThemeForSaveWatch() string {
	if name := paths.Setting("SENDA_THEME"); name != "" {
		return name
	}
	return theme.DefaultTheme
}

func themeFieldError(field string, err error) error {
	return &theme.ValidationError{Field: field, Message: err.Error()}
}

func safeThemeName(name string) bool {
	return len(name) <= 40 && regexp.MustCompile(`^[a-z0-9]+(-[a-z0-9]+)*$`).MatchString(name)
}

func saveUserTheme(input themeSaveInput, options themeSaveOptions) (theme.Info, error) {
	fail := func(field, message string) (theme.Info, error) {
		return theme.Info{}, themeFieldError(field, errors.New(message))
	}
	if !safeThemeName(input.Name) || (input.Original != "" && !safeThemeName(input.Original)) {
		return fail("name", "invalid theme name")
	}
	for _, name := range []string{input.Name, input.Original} {
		if name == "" {
			continue
		}
		if _, err := os.Lstat(filepath.Join(options.dirs.Builtin, name)); err == nil {
			return fail("name", "name is reserved by a builtin theme")
		} else if !os.IsNotExist(err) {
			return theme.Info{}, err
		}
	}
	target := filepath.Join(options.dirs.User, input.Name)
	_, targetErr := os.Lstat(target)
	if targetErr == nil && input.Name != input.Original {
		return fail("name", "theme name already exists")
	}
	if targetErr != nil && !os.IsNotExist(targetErr) {
		return theme.Info{}, targetErr
	}
	if input.Original != "" {
		stat, err := os.Lstat(filepath.Join(options.dirs.User, input.Original))
		if err != nil || !stat.IsDir() {
			return fail("name", "original user theme does not exist")
		}
	}
	if err := os.MkdirAll(options.dirs.User, 0700); err != nil {
		return theme.Info{}, err
	}
	temp, err := os.MkdirTemp(options.dirs.User, ".tmp-"+input.Name+"-")
	if err != nil {
		return theme.Info{}, err
	}
	defer os.RemoveAll(temp)
	source, err := os.Open(input.Wallpaper)
	if err != nil {
		return theme.Info{}, themeFieldError("wallpaper", err)
	}
	defer source.Close()
	_, format, err := image.Decode(source)
	if err != nil {
		return theme.Info{}, themeFieldError("wallpaper", err)
	}
	if _, err := source.Seek(0, io.SeekStart); err != nil {
		return theme.Info{}, err
	}
	wallpaper := "wallpaper." + format
	dest, err := os.Create(filepath.Join(temp, wallpaper))
	if err != nil {
		return theme.Info{}, err
	}
	_, copyErr := io.Copy(dest, source)
	closeErr := dest.Close()
	if err := errors.Join(copyErr, closeErr); err != nil {
		return theme.Info{}, err
	}
	value := theme.Theme{Name: input.Name, Wallpaper: wallpaper, Colors: input.Colors}
	data, err := json.Marshal(value)
	if err != nil {
		return theme.Info{}, err
	}
	if err := os.WriteFile(filepath.Join(temp, "theme.json"), data, 0600); err != nil {
		return theme.Info{}, err
	}
	loaded, err := theme.Load(filepath.Join(temp, "theme.json"))
	if err == nil {
		err = theme.Validate(loaded, temp, input.Name)
	}
	if err != nil {
		return theme.Info{}, err
	}
	rename := options.rename
	if rename == nil {
		rename = os.Rename
	}
	backup := ""
	if targetErr == nil {
		backup, err = os.MkdirTemp(options.dirs.User, ".bak-"+input.Name+"-")
		if err != nil {
			return theme.Info{}, err
		}
		if err := os.Remove(backup); err != nil {
			return theme.Info{}, err
		}
		if err := rename(target, backup); err != nil {
			return theme.Info{}, err
		}
	}
	if err := rename(temp, target); err != nil {
		if backup != "" {
			err = errors.Join(err, rename(backup, target))
		}
		return theme.Info{}, err
	}
	if input.Original != "" && input.Original != input.Name {
		if options.active == input.Original {
			if err := config.Set(options.configFile, map[string]string{"SENDA_THEME": input.Name}); err != nil {
				return theme.Info{}, err
			}
			options.active = input.Name
		}
		if err := os.RemoveAll(filepath.Join(options.dirs.User, input.Original)); err != nil {
			return theme.Info{}, err
		}
	}
	if backup != "" {
		if err := os.RemoveAll(backup); err != nil {
			return theme.Info{}, err
		}
	}
	dir, err := filepath.Abs(target)
	if err != nil {
		return theme.Info{}, err
	}
	return theme.Info{Name: input.Name, Active: options.active == input.Name, Valid: true, Dir: dir, File: filepath.Join(dir, "theme.json"), Wallpaper: theme.WallpaperPath(value, dir), Colors: value.Colors}, nil
}
