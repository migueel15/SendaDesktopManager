// Package themeexport renders the active Senda theme into configuration
// files for other applications (terminals, GTK, Qt, Hyprland, Neovim).
package themeexport

import (
	"io"

	"bytes"
	"context"
	"embed"
	"fmt"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"text/template"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
)

//go:embed all:templates
var builtinTemplates embed.FS

// Dirs locates user templates and the generated output.
type Dirs struct{ Templates, Output string }

func DefaultDirs() Dirs {
	return Dirs{
		Templates: filepath.Join(paths.ConfigDir(), "templates"),
		Output:    filepath.Join(paths.ConfigDir(), "generated"),
	}
}

var funcs = template.FuncMap{
	"mix":     mix,
	"lighten": lighten,
	"darken":  darken,
	"bare":    func(c string) string { return strings.TrimPrefix(c, "#") },
	// contrast picks the dark or light candidate that reads best on bg.
	"contrast": func(bg, dark, light string) string {
		if luminance(bg) > 0.3 {
			return dark
		}
		return light
	},
	// rgb writes "r,g,b", the format of KDE color schemes.
	"rgb": func(c string) string {
		v := mustHex(c)
		return fmt.Sprintf("%d,%d,%d", int(v.r*255+0.5), int(v.g*255+0.5), int(v.b*255+0.5))
	},
	"rgba": func(c string, alpha float64) string {
		v := mustHex(c)
		return fmt.Sprintf("rgba(%d, %d, %d, %g)", int(v.r*255+0.5), int(v.g*255+0.5), int(v.b*255+0.5), alpha)
	},
}

// templateSources maps each output path to its template text. A user template
// with the same relative path replaces the builtin one; other user files are
// added as new outputs.
func templateSources(userDir string) (map[string]string, error) {
	sources := map[string]string{}
	root, _ := fs.Sub(builtinTemplates, "templates")
	collect := func(fsys fs.FS) error {
		return fs.WalkDir(fsys, ".", func(path string, entry fs.DirEntry, err error) error {
			if err != nil || entry.IsDir() {
				return err
			}
			data, err := fs.ReadFile(fsys, path)
			if err != nil {
				return err
			}
			sources[filepath.FromSlash(path)] = string(data)
			return nil
		})
	}
	if err := collect(root); err != nil {
		return nil, err
	}
	if stat, err := os.Stat(userDir); err == nil && stat.IsDir() {
		if err := collect(os.DirFS(userDir)); err != nil {
			return nil, fmt.Errorf("templates: %w", err)
		}
	}
	return sources, nil
}

// Render returns the rendered content of every template, keyed by relative path.
func Render(palette Palette, userDir string) (map[string][]byte, error) {
	sources, err := templateSources(userDir)
	if err != nil {
		return nil, err
	}
	result := make(map[string][]byte, len(sources))
	for path, text := range sources {
		tmpl, err := template.New(path).Funcs(funcs).Option("missingkey=error").Parse(text)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", path, err)
		}
		var out bytes.Buffer
		if err := tmpl.Execute(&out, palette); err != nil {
			return nil, fmt.Errorf("%s: %w", path, err)
		}
		result[path] = out.Bytes()
	}
	return result, nil
}

// Export renders every template for the theme and writes the results under
// dirs.Output. Each file is replaced atomically so readers never see a partial
// file. It returns the written paths, sorted.
func Export(name string, colors map[string]string, dirs Dirs) (written []string, err error) {
	defer func() {
		// Color helpers panic on malformed hex; themes are validated before
		// export, so this only guards against hand-written user templates.
		if r := recover(); r != nil {
			err = fmt.Errorf("export: %v", r)
		}
	}()
	rendered, err := Render(Derive(name, colors), dirs.Templates)
	if err != nil {
		return nil, err
	}
	for rel, content := range rendered {
		target := filepath.Join(dirs.Output, rel)
		if err := writeAtomic(target, content); err != nil {
			return nil, err
		}
		written = append(written, target)
	}
	sort.Strings(written)
	return written, nil
}

func writeAtomic(target string, content []byte) error {
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(target), "."+filepath.Base(target)+".*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(content); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(0o644); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), target)
}

// Runner executes an external command; tests replace it.
type Runner func(ctx context.Context, name string, args ...string) error

func ExecRunner(ctx context.Context, name string, args ...string) error {
	return exec.CommandContext(ctx, name, args...).Run()
}

// Reload asks running applications to pick up the new files. Every step is
// best effort: a missing program or instance is not an error.
func Reload(run Runner) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	// kitty rereads its configuration, including included files, on SIGUSR1.
	_ = run(ctx, "pkill", "-USR1", "-x", "kitty")
	if hyprctl.InSession() {
		hypr := hyprctl.New(func(ctx context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
			return nil, run(ctx, name, args...)
		})
		_ = hypr.Reload(ctx)
	}
	// Only Neovim instances already using the senda colorscheme reload it.
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		return
	}
	sockets, _ := filepath.Glob(filepath.Join(runtime, "nvim.*"))
	for _, socket := range sockets {
		_ = run(ctx, "nvim", "--server", socket, "--remote-expr",
			`execute('if get(g:, "colors_name", "") ==# "senda" | colorscheme senda | endif')`)
	}
}
