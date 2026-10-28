package main

import (
	"encoding/json"
	"image"
	"os"
	"path/filepath"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/screenshot"
)

func TestScreenshotCropOnlyCachesUntilSave(t *testing.T) {
	base := t.TempDir()
	t.Setenv("HOME", base)
	t.Setenv("XDG_CACHE_HOME", filepath.Join(base, "cache"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(base, "config"))
	t.Setenv("SENDA_SCREENSHOT_DIR", filepath.Join(base, "saved"))
	input := filepath.Join(base, "input.png")
	if err := screenshot.Write(input, image.NewNRGBA(image.Rect(0, 0, 8, 6))); err != nil {
		t.Fatal(err)
	}
	args := []string{"crop", "--in", input, "--x", "2", "--y", "1", "--w", "3", "--h", "4"}
	out, err := runCommand(t, screenshotCmd(), args...)
	if err != nil {
		t.Fatalf("%s %v", out, err)
	}
	var result map[string]string
	if err = json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatal(err)
	}
	img, err := screenshot.Read(result["path"])
	if err != nil || img.Bounds() != image.Rect(0, 0, 3, 4) {
		t.Fatalf("crop: %v", err)
	}
	if _, err = os.Stat(filepath.Join(base, "saved")); !os.IsNotExist(err) {
		t.Fatal("created saved directory before Save")
	}
	args = append(args, "--save")
	out, err = runCommand(t, screenshotCmd(), args...)
	if err != nil {
		t.Fatalf("%s %v", out, err)
	}
	if err = json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatal(err)
	}
	if filepath.Dir(result["path"]) != filepath.Join(base, "saved") {
		t.Fatal(result)
	}
	if _, err = screenshot.Read(result["path"]); err != nil {
		t.Fatal(err)
	}
}

func TestScreenshotRejectsInvalidGeometry(t *testing.T) {
	input := filepath.Join(t.TempDir(), "input.png")
	if err := screenshot.Write(input, image.NewNRGBA(image.Rect(0, 0, 8, 6))); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"--x", "5", "--w", "-2", "--h", "2"},
		{"--x", "-1", "--w", "2", "--h", "2"},
		{"--w", "9", "--h", "2"},
		{"--w", "2", "--h", "0"},
	} {
		if out, err := runCommand(t, screenshotCmd(), append([]string{"crop", "--in", input}, args...)...); err == nil {
			t.Fatalf("accepted geometry %v: %s", args, out)
		}
	}
}

func TestEditorCopyDoesNotWriteFiles(t *testing.T) {
	base := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", filepath.Join(base, "cache"))
	t.Setenv("PATH", base)
	// Capture stdin and arguments to verify the real PNG clipboard protocol.
	copyPath := filepath.Join(base, "clipboard.png")
	argsPath := filepath.Join(base, "arguments")
	t.Setenv("TEST_CLIPBOARD", copyPath)
	t.Setenv("TEST_ARGUMENTS", argsPath)
	if err := os.WriteFile(filepath.Join(base, "wl-copy"), []byte("#!/bin/sh\nprintf '%s %s' \"$1\" \"$2\" > \"$TEST_ARGUMENTS\"\n/bin/cat > \"$TEST_CLIPBOARD\"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	input := filepath.Join(base, "input.png")
	if err := screenshot.Write(input, image.NewNRGBA(image.Rect(0, 0, 8, 6))); err != nil {
		t.Fatal(err)
	}
	if out, err := runCommand(t, screenshotCmd(), "crop", "--in", input, "--w", "3", "--h", "4", "--copy", "--cache=false"); err != nil {
		t.Fatalf("%s %v", out, err)
	}
	got, err := screenshot.Read(copyPath)
	if err != nil || got.Bounds() != image.Rect(0, 0, 3, 4) {
		t.Fatalf("clipboard PNG: %v", err)
	}
	args, err := os.ReadFile(argsPath)
	if err != nil || string(args) != "--type image/png" {
		t.Fatalf("arguments %s %v", args, err)
	}
	if _, err = os.Stat(filepath.Join(base, "cache")); !os.IsNotExist(err) {
		t.Fatal("editor copy wrote cache")
	}
}
