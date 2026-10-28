package screenshot

import (
	"context"
	"image"
	"image/color"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestCropPixelsAndBounds(t *testing.T) {
	src := image.NewNRGBA(image.Rect(0, 0, 8, 6))
	src.SetNRGBA(3, 2, color.NRGBA{12, 34, 56, 78})
	got, err := Crop(src, image.Rect(3, 2, 7, 5))
	if err != nil {
		t.Fatal(err)
	}
	if got.Bounds() != image.Rect(0, 0, 4, 3) || got.At(0, 0) != src.At(3, 2) {
		t.Fatalf("wrong crop: %v %v", got.Bounds(), got.At(0, 0))
	}
	for _, rect := range []image.Rectangle{image.Rect(0, 0, 0, 1), image.Rect(-1, 0, 2, 2), image.Rect(0, 0, 9, 6), image.Rect(1, 6, 2, 7)} {
		if _, err := Crop(src, rect); err == nil {
			t.Fatalf("accepted %v", rect)
		}
	}
	// Subimages need not start at the origin.
	if got, err := Crop(src.SubImage(image.Rect(2, 1, 8, 6)), image.Rect(3, 2, 5, 4)); err != nil || got.At(0, 0) != src.At(3, 2) {
		t.Fatalf("subimage: %v", err)
	}
}

func TestSaveNamesNeverOverwrite(t *testing.T) {
	now := time.Date(2026, 10, 28, 9, 4, 3, 0, time.Local)
	if got := Name(now); got != "captura-2026-10-28-090403.png" {
		t.Fatal(got)
	}
	dir := filepath.Join(t.TempDir(), "pictures", "captures")
	src := image.NewNRGBA(image.Rect(0, 0, 2, 2))
	first, err := Save(src, dir, now)
	if err != nil {
		t.Fatal(err)
	}
	src.SetNRGBA(0, 0, color.NRGBA{R: 255, A: 255})
	second, err := Save(src, dir, now)
	if err != nil {
		t.Fatal(err)
	}
	if first == second {
		t.Fatal("overwrote original")
	}
	original, err := Read(first)
	if err != nil {
		t.Fatal(err)
	}
	if original.At(0, 0) == src.At(0, 0) {
		t.Fatal("modified previous capture")
	}
	info, _ := os.Stat(first)
	if info.Mode().Perm() != 0600 {
		t.Fatal(info.Mode())
	}
}

func TestPrivateCacheRetentionAndCleanupBoundary(t *testing.T) {
	base := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", base)
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	src := image.NewNRGBA(image.Rect(0, 0, 1, 1))
	for i := 0; i < 8; i++ {
		if _, err := Cache(src); err != nil {
			t.Fatal(err)
		}
	}
	dir, _ := CacheDir()
	entries, _ := os.ReadDir(dir)
	if len(entries) != 5 {
		t.Fatalf("retained %d captures", len(entries))
	}
	info, _ := os.Stat(dir)
	if info.Mode().Perm() != 0700 {
		t.Fatal(info.Mode())
	}
	if err := Cleanup(base); err == nil {
		t.Fatal("accepted arbitrary cleanup")
	}
	if err := Cleanup(filepath.Join(os.Getenv("XDG_RUNTIME_DIR"), "senda", "screenshots", "capture-safe")); err != nil {
		t.Fatal(err)
	}
}

func TestDefaultDirectory(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("PATH", t.TempDir())
	got, err := DefaultDirectory(context.Background(), "")
	if err != nil || got != filepath.Join(home, "Pictures", "Capturas") {
		t.Fatalf("%s %v", got, err)
	}
	got, err = DefaultDirectory(context.Background(), "~/my pictures")
	if err != nil || got != filepath.Join(home, "my pictures") {
		t.Fatalf("%s %v", got, err)
	}
	if _, err = DefaultDirectory(context.Background(), "relative"); err == nil {
		t.Fatal("accepted relative path")
	}
}

func TestFreezeFailureRemovesSession(t *testing.T) {
	runtime := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", runtime)
	t.Setenv("PATH", t.TempDir())
	if _, err := Freeze(context.Background(), []string{"fake-output"}); err == nil {
		t.Fatal("expected missing grim")
	}
	entries, err := os.ReadDir(filepath.Join(runtime, "senda", "screenshots"))
	if err != nil || len(entries) != 0 {
		t.Fatalf("left private frames: %v %v", entries, err)
	}
}
