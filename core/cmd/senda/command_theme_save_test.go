package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
)

func saveFixture(t *testing.T) (themeSaveInput, themeSaveOptions) {
	t.Helper()
	root := t.TempDir()
	options := themeSaveOptions{dirs: theme.Dirs{Builtin: filepath.Join(root, "builtin"), User: filepath.Join(root, "user")}, configFile: filepath.Join(root, "config"), active: theme.DefaultTheme, rename: os.Rename}
	input := themeSaveInput{Name: "custom", Wallpaper: filepath.Join(root, "theme.json"), Colors: map[string]string{}}
	for _, key := range theme.ColorKeys {
		input.Colors[key] = "#123456"
	}
	writeThemeImage(t, input.Wallpaper, 2)
	return input, options
}

func writeThemeImage(t *testing.T, path string, size int) {
	t.Helper()
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	err = png.Encode(f, image.NewRGBA(image.Rect(0, 0, size, size)))
	closeErr := f.Close()
	modified := time.Unix(1700000000+int64(size), 0)
	if err := os.Chtimes(path, modified, modified); err != nil {
		t.Fatal(err)
	}
	if err != nil || closeErr != nil {
		t.Fatalf("encode: %v, close: %v", err, closeErr)
	}
}

func TestThemeSaveCreateEditRename(t *testing.T) {
	for _, active := range []bool{false, true} {
		t.Run(map[bool]string{false: "inactive", true: "active"}[active], func(t *testing.T) {
			input, options := saveFixture(t)
			info, err := saveUserTheme(input, options)
			if err != nil {
				t.Fatal(err)
			}
			if !info.Valid || info.Active || info.Builtin || filepath.Base(info.Wallpaper) != "wallpaper.png" {
				t.Fatal(info)
			}
			source, _ := os.ReadFile(input.Wallpaper)
			copied, _ := os.ReadFile(info.Wallpaper)
			if !bytes.Equal(source, copied) {
				t.Fatal("wallpaper not copied")
			}
			input.Original = input.Name
			input.Wallpaper = info.Wallpaper
			input.Colors["base"] = "#abcdef"
			info, err = saveUserTheme(input, options)
			if err != nil {
				t.Fatal(err)
			}
			loaded, err := theme.Load(info.File)
			if err != nil || loaded.Colors["base"] != "#abcdef" {
				t.Fatalf("%+v %v", loaded, err)
			}
			if active {
				options.active = input.Name
			}
			old := info.Dir
			input.Name = "renamed"
			info, err = saveUserTheme(input, options)
			if err != nil {
				t.Fatal(err)
			}
			if info.Active != active {
				t.Fatal(info)
			}
			if _, err := os.Stat(old); !os.IsNotExist(err) {
				t.Fatal("original remains", err)
			}
			if active {
				values, err := config.Load(options.configFile)
				if err != nil || values["SENDA_THEME"] != "renamed" {
					t.Fatalf("%v %v", values, err)
				}
			}
			entries, _ := os.ReadDir(options.dirs.User)
			if len(entries) != 1 {
				t.Fatal("staging or backup remains", entries)
			}
		})
	}
}

func TestThemeSaveRejectsWithoutResidue(t *testing.T) {
	for _, kind := range []string{"builtin", "occupied", "colors", "bad-name", "bad-original", "missing-original"} {
		t.Run(kind, func(t *testing.T) {
			input, options := saveFixture(t)
			want := "name"
			switch kind {
			case "builtin":
				if err := os.MkdirAll(filepath.Join(options.dirs.Builtin, input.Name), 0700); err != nil {
					t.Fatal(err)
				}
			case "occupied":
				if _, err := saveUserTheme(input, options); err != nil {
					t.Fatal(err)
				}
			case "colors":
				input.Colors["base"] = "bad"
				want = "colors.base"
			case "bad-name":
				input.Name = "../escape"
			case "bad-original":
				input.Original = "../escape"
			case "missing-original":
				input.Original = "missing"
			}
			before := theme.Discover(options.dirs)
			_, err := saveUserTheme(input, options)
			var validation *theme.ValidationError
			if !errors.As(err, &validation) || validation.Field != want {
				t.Fatalf("error = %v, want %s", err, want)
			}
			if after := theme.Discover(options.dirs); !reflect.DeepEqual(before, after) {
				t.Fatalf("changed themes: %v -> %v", before, after)
			}
			entries, _ := os.ReadDir(options.dirs.User)
			for _, entry := range entries {
				if strings.HasPrefix(entry.Name(), ".") {
					t.Fatal("residue", entry.Name())
				}
			}
		})
	}
}

func TestThemeSaveInstallFailureRestoresOriginal(t *testing.T) {
	input, options := saveFixture(t)
	info, err := saveUserTheme(input, options)
	if err != nil {
		t.Fatal(err)
	}
	before, _ := os.ReadFile(info.File)
	input.Original = input.Name
	input.Wallpaper = info.Wallpaper
	input.Colors["base"] = "#abcdef"
	options.rename = func(from, to string) error {
		if strings.HasPrefix(filepath.Base(from), ".tmp-") {
			return errors.New("simulated install failure")
		}
		return os.Rename(from, to)
	}
	if _, err := saveUserTheme(input, options); err == nil {
		t.Fatal("expected failure")
	}
	after, err := os.ReadFile(info.File)
	if err != nil || !bytes.Equal(before, after) {
		t.Fatalf("original lost: %v", err)
	}
	if _, err := theme.Load(info.File); err != nil {
		t.Fatal(err)
	}
	entries, _ := os.ReadDir(options.dirs.User)
	if len(entries) != 1 {
		t.Fatal(entries)
	}
}

func TestThemeSaveCommandJSON(t *testing.T) {
	input, _ := saveFixture(t)
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("SENDA_HOME", t.TempDir())
	t.Setenv("SENDA_THEME", "custom")
	raw, _ := json.Marshal(input)
	cmd := themeSaveCmd()
	cmd.SetArgs([]string{"--json", "--no-reload"})
	cmd.SetIn(bytes.NewReader(raw))
	var out bytes.Buffer
	cmd.SetOut(&out)
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	var info theme.Info
	if err := json.Unmarshal(out.Bytes(), &info); err != nil || !info.Valid || !info.Active {
		t.Fatalf("%s %v", out.String(), err)
	}
}
