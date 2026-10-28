// Package screenshot handles private capture files and lossless PNG cropping.
package screenshot

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/draw"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const KeyDirectory = "SENDA_SCREENSHOT_DIR"

func Name(now time.Time) string { return "captura-" + now.Format("2006-01-02-150405") + ".png" }

// Crop rejects empty and out-of-bounds rectangles instead of silently clipping.
func Crop(src image.Image, rect image.Rectangle) (image.Image, error) {
	if rect.Empty() || !rect.In(src.Bounds()) {
		return nil, fmt.Errorf("el recorte está fuera de la imagen o vacío")
	}
	dst := image.NewNRGBA(image.Rect(0, 0, rect.Dx(), rect.Dy()))
	draw.Draw(dst, dst.Bounds(), src, rect.Min, draw.Src)
	return dst, nil
}

func Read(path string) (image.Image, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return png.Decode(f)
}

func Write(path string, img image.Image) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}
	err = png.Encode(f, img)
	closeErr := f.Close()
	if err != nil {
		os.Remove(path)
		return err
	}
	if closeErr != nil {
		os.Remove(path)
		return closeErr
	}
	return nil
}

func privateDir(path string) (string, error) {
	if err := os.MkdirAll(path, 0700); err != nil {
		return "", err
	}
	info, err := os.Lstat(path)
	if err != nil {
		return "", err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return "", fmt.Errorf("directorio privado inválido")
	}
	if err := os.Chmod(path, 0700); err != nil {
		return "", err
	}
	return path, nil
}

func CacheDir() (string, error) {
	base := os.Getenv("XDG_CACHE_HOME")
	if !filepath.IsAbs(base) {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		base = filepath.Join(home, ".cache")
	}
	return privateDir(filepath.Join(base, "senda", "screenshots"))
}

// Freeze completes every grim invocation before returning paths to the UI.
// A failure removes the entire session, so no partial overlay can be shown.
func Freeze(ctx context.Context, outputs []string) (paths []string, err error) {
	base := os.Getenv("XDG_RUNTIME_DIR")
	if !filepath.IsAbs(base) {
		return nil, fmt.Errorf("XDG_RUNTIME_DIR debe ser una ruta absoluta")
	}
	root, err := privateDir(filepath.Join(base, "senda", "screenshots"))
	if err != nil {
		return nil, err
	}
	dir, err := os.MkdirTemp(root, "capture-")
	if err != nil {
		return nil, err
	}
	defer func() {
		if err != nil {
			os.RemoveAll(dir)
		}
	}()
	for i, output := range outputs {
		path := filepath.Join(dir, fmt.Sprintf("output-%d.png", i))
		// Pre-create privately: grim truncates the existing file.
		f, e := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
		if e != nil {
			return nil, e
		}
		f.Close()
		if e = exec.CommandContext(ctx, "grim", "-o", output, path).Run(); e != nil {
			return nil, fmt.Errorf("capturar %s: %w", output, e)
		}
		paths = append(paths, path)
	}
	return paths, nil
}

func Cleanup(path string) error {
	base := os.Getenv("XDG_RUNTIME_DIR")
	if !filepath.IsAbs(base) {
		return fmt.Errorf("XDG_RUNTIME_DIR inválido")
	}
	root := filepath.Join(base, "senda", "screenshots")
	dir := filepath.Clean(path)
	if filepath.Dir(dir) != root || !strings.HasPrefix(filepath.Base(dir), "capture-") {
		return fmt.Errorf("sesión temporal inválida")
	}
	return os.RemoveAll(dir)
}

// Cache keeps five immutable captures. Names are random so edits cannot mutate
// an image that a pending notification still references.
func Cache(img image.Image) (string, error) {
	dir, err := CacheDir()
	if err != nil {
		return "", err
	}
	f, err := os.CreateTemp(dir, "capture-*.png")
	if err != nil {
		return "", err
	}
	path := f.Name()
	err = png.Encode(f, img)
	closeErr := f.Close()
	if err != nil || closeErr != nil {
		os.Remove(path)
		if err != nil {
			return "", err
		}
		return "", closeErr
	}
	entries, _ := os.ReadDir(dir)
	type entry struct {
		path     string
		modified time.Time
	}
	var captures []entry
	for _, e := range entries {
		if !e.Type().IsRegular() || !strings.HasPrefix(e.Name(), "capture-") || !strings.HasSuffix(e.Name(), ".png") {
			continue
		}
		info, e2 := e.Info()
		if e2 == nil {
			captures = append(captures, entry{filepath.Join(dir, e.Name()), info.ModTime()})
		}
	}
	sort.Slice(captures, func(i, j int) bool { return captures[i].modified.After(captures[j].modified) })
	for _, e := range captures[min(5, len(captures)):] {
		if e.path != path {
			os.Remove(e.path)
		}
	}
	return path, nil
}

func Copy(ctx context.Context, img image.Image) error {
	var data bytes.Buffer
	if err := png.Encode(&data, img); err != nil {
		return err
	}
	cmd := exec.CommandContext(ctx, "wl-copy", "--type", "image/png")
	cmd.Stdin = &data
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("copiar captura: %w", err)
	}
	return nil
}

func DefaultDirectory(ctx context.Context, configured string) (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	if configured != "" {
		if strings.HasPrefix(configured, "~/") {
			configured = filepath.Join(home, configured[2:])
		}
		if !filepath.IsAbs(configured) {
			return "", fmt.Errorf("la ruta de capturas debe ser absoluta o empezar por ~/")
		}
		return filepath.Clean(configured), nil
	}
	pictures := filepath.Join(home, "Pictures")
	if out, err := exec.CommandContext(ctx, "xdg-user-dir", "PICTURES").Output(); err == nil && filepath.IsAbs(strings.TrimSpace(string(out))) {
		pictures = strings.TrimSpace(string(out))
	}
	return filepath.Join(pictures, "Capturas"), nil
}

func Save(img image.Image, dir string, now time.Time) (string, error) {
	if err := os.MkdirAll(dir, 0700); err != nil {
		return "", err
	}
	// Preserve existing captures taken in the same second, including on restart.
	for i := 0; i < 86400; i++ {
		path := filepath.Join(dir, Name(now.Add(time.Duration(i)*time.Second)))
		err := Write(path, img)
		if os.IsExist(err) {
			continue
		}
		return path, err
	}
	return "", fmt.Errorf("no se encontró un nombre de captura libre")
}
