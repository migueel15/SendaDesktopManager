package main

import (
	"bytes"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/wallpaper"
)

func TestWallpaperParsers(t *testing.T) {
	for _, value := range []string{"0,0", "100,200", "-10,20"} {
		if _, err := parsePosition(value); err != nil {
			t.Errorf("position %q: %v", value, err)
		}
	}
	if pos, err := parsePosition("100,200"); err != nil || pos != (wallpaper.Position{X: 100, Y: 200}) {
		t.Fatalf("position = %v, %v", pos, err)
	}
	for _, value := range []string{"", "1", "1,2,3", "a,2", "1,b", "1.5,2", "999999999999999999999999,0"} {
		if _, err := parsePosition(value); err == nil {
			t.Errorf("accepted position %q", value)
		}
	}
	for _, value := range []string{"none", "fade", "wipe", "wave", "grow", "center", "any", "outer", "random"} {
		if kind, err := parseAnimationKind(value); err != nil || string(kind) != value {
			t.Errorf("kind %q: %v, %v", value, kind, err)
		}
	}
	for _, value := range []string{"", "unknown", "FADE"} {
		if _, err := parseAnimationKind(value); err == nil {
			t.Errorf("accepted kind %q", value)
		}
	}
	for _, value := range []string{"crop", "fit", "stretch", "none"} {
		if mode, err := parseResizeMode(value); err != nil || string(mode) != value {
			t.Errorf("resize %q: %v, %v", value, mode, err)
		}
	}
	for _, value := range []string{"", "zoom"} {
		if _, err := parseResizeMode(value); err == nil {
			t.Errorf("accepted resize %q", value)
		}
	}
	for _, value := range []string{".61,.18,.48,.9", "0,-2,1,3"} {
		if _, err := parseBezier(value); err != nil {
			t.Errorf("bezier %q: %v", value, err)
		}
	}
	if curve, err := parseBezier(".61,.18,.48,.9"); err != nil || curve != ([4]float64{.61, .18, .48, .9}) {
		t.Fatalf("bezier = %v, %v", curve, err)
	}
	for _, value := range []string{"", "1,2,3", "1,2,3,4,5", "a,0,1,0", "-0.1,0,1,0", "0,0,1.1,0", "NaN,0,1,0", "0,Inf,1,0", "0,0,1,-Inf"} {
		if _, err := parseBezier(value); err == nil {
			t.Errorf("accepted bezier %q", value)
		}
	}
	for _, duration := range []time.Duration{0, time.Millisecond, 3 * time.Second} {
		if err := validateTransitionDuration(duration); err != nil {
			t.Error(err)
		}
	}
	if err := validateTransitionDuration(-time.Millisecond); err == nil {
		t.Error("accepted negative duration")
	}
}

func TestWallpaperSetRejectsInvalidOptionsBeforeIPC(t *testing.T) {
	for _, flags := range [][]string{
		{"--pos=bad"}, {"--pos="}, {"--transition-type=bad"}, {"--resize=zoom"},
		{"--transition-bezier=0,0,2,1"}, {"--transition-duration=-1s"}, {"--transition-duration=bad"},
	} {
		cmd := newWallpaperSetCmd()
		cmd.SetOut(&bytes.Buffer{})
		cmd.SetErr(&bytes.Buffer{})
		cmd.SetArgs(append(flags, "missing.png"))
		err := cmd.Execute()
		if err == nil || strings.Contains(err.Error(), "invalid wallpaper") || strings.Contains(err.Error(), "shell") {
			t.Errorf("flags %v: %v", flags, err)
		}
	}
}

func TestWallpaperSetChecksImageAndDefaults(t *testing.T) {
	cmd := newWallpaperSetCmd()
	for flag, want := range map[string]string{"transition-type": "none", "transition-duration": "3s", "transition-bezier": ".61,.18,.48,.9", "resize": "crop", "monitor": ""} {
		if got := cmd.Flags().Lookup(flag).DefValue; got != want {
			t.Errorf("%s = %q, want %q", flag, got, want)
		}
	}
	if !strings.Contains(cmd.Flags().Lookup("transition-fps").Usage, "no effect") {
		t.Fatal("fps help does not explain compatibility")
	}
	path := filepath.Join(t.TempDir(), "invalid.png")
	if err := os.WriteFile(path, []byte("invalid"), 0600); err != nil {
		t.Fatal(err)
	}
	cmd.SetOut(&bytes.Buffer{})
	cmd.SetErr(&bytes.Buffer{})
	cmd.SetArgs([]string{path})
	if err := cmd.Execute(); err == nil || !strings.Contains(err.Error(), "invalid wallpaper") {
		t.Fatalf("image error: %v", err)
	}
}

func TestWallpaperSetReportsShellUnavailable(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	var data bytes.Buffer
	if err := png.Encode(&data, image.NewRGBA(image.Rect(0, 0, 1, 1))); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "image.png")
	if err := os.WriteFile(path, data.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}
	cmd := newWallpaperSetCmd()
	cmd.SetOut(&bytes.Buffer{})
	cmd.SetErr(&bytes.Buffer{})
	cmd.SetArgs([]string{path, "--transition-fps=144"})
	if err := cmd.Execute(); err == nil || !strings.Contains(err.Error(), "Senda shell is not running") {
		t.Fatalf("shell error: %v", err)
	}
}

func TestImportWallpaperKeepsAnIndependentCopy(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "wallpapers")
	writePNG := func(path string, width int) {
		t.Helper()
		var data bytes.Buffer
		if err := png.Encode(&data, image.NewRGBA(image.Rect(0, 0, width, 1))); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, data.Bytes(), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	source := filepath.Join(root, "foto.dat")
	writePNG(source, 1)
	first, err := importWallpaper(source, dir)
	if err != nil || first != filepath.Join(dir, "foto.png") {
		t.Fatalf("first = %q, %v", first, err)
	}
	if again, err := importWallpaper(source, dir); err != nil || again != first {
		t.Fatalf("again = %q, %v", again, err)
	}
	writePNG(source, 2)
	second, err := importWallpaper(source, dir)
	if err != nil || second != filepath.Join(dir, "foto-2.png") {
		t.Fatalf("second = %q, %v", second, err)
	}
	if err := os.Remove(source); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(first); err != nil {
		t.Fatal(err)
	}
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) != 2 {
		t.Fatalf("entries = %v, %v", entries, err)
	}
	invalid := filepath.Join(root, "nota.txt")
	if err := os.WriteFile(invalid, []byte("texto"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := importWallpaper(invalid, dir); err == nil {
		t.Fatal("accepted a file that is not an image")
	}
}
