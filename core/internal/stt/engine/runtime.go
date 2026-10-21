package engine

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

const (
	sherpaVersion = "1.13.8"
	cudaVersion   = "1.13.8+cuda13.cudnn9.onnxruntime1.28.2"
	cudaWheelURL  = "https://k2-fsa.github.io/sherpa/onnx/cuda.html"
	manifestName  = "runtime.json"
)

type runtimeManifest struct {
	Provider   string `json:"provider"`
	SherpaOnnx string `json:"sherpaOnnx"`
}

// runtimeRunner is replaceable in package tests so no Python installation is needed.
var runtimeRunner stt.Runner = stt.ExecRunner

func runtimePython(dir string) string { return filepath.Join(dir, "bin", "python") }

func installedRuntime(dir string) (runtimeManifest, bool) {
	var m runtimeManifest
	data, err := os.ReadFile(filepath.Join(dir, manifestName))
	if err != nil || json.Unmarshal(data, &m) != nil {
		return m, false
	}
	if (m.Provider != "cpu" || m.SherpaOnnx != sherpaVersion) &&
		(m.Provider != "cuda" || m.SherpaOnnx != cudaVersion) {
		return m, false
	}
	info, err := os.Stat(runtimePython(dir))
	return m, err == nil && info.Mode().IsRegular() && info.Mode().Perm()&0o111 != 0
}

func RuntimeInstalled() bool {
	_, ok := installedRuntime(stt.RuntimeDir())
	return ok
}

func RuntimeProvider() string {
	m, ok := installedRuntime(stt.RuntimeDir())
	if !ok {
		return ""
	}
	return m.Provider
}

func Python() string {
	if !RuntimeInstalled() {
		return ""
	}
	return runtimePython(stt.RuntimeDir())
}

func runRuntime(ctx context.Context, output io.Writer, name string, args ...string) error {
	data, err := runtimeRunner(ctx, nil, name, args...)
	if len(data) > 0 {
		if _, writeErr := output.Write(data); writeErr != nil {
			return writeErr
		}
		if data[len(data)-1] != '\n' {
			if _, writeErr := io.WriteString(output, "\n"); writeErr != nil {
				return writeErr
			}
		}
	}
	if err != nil {
		var exit *exec.ExitError
		if errors.As(err, &exit) && len(exit.Stderr) > 0 {
			_, _ = output.Write(exit.Stderr)
		}
		return fmt.Errorf("%s %s: %w", name, strings.Join(args, " "), err)
	}
	return nil
}

func installWheel(ctx context.Context, output io.Writer, python, provider string) error {
	args := []string{"-m", "pip", "install", "--force-reinstall"}
	if provider == "cuda" {
		args = append(args, "numpy", "sherpa-onnx=="+cudaVersion, "-f", cudaWheelURL)
	} else {
		args = append(args, "sherpa-onnx=="+sherpaVersion)
	}
	if err := runRuntime(ctx, output, python, args...); err != nil {
		return err
	}
	return runRuntime(ctx, output, python, "-c", "import sherpa_onnx")
}

// InstallRuntime builds and verifies a new venv before replacing the current one.
func InstallRuntime(ctx context.Context, output io.Writer) error {
	if output == nil {
		output = io.Discard
	}
	dir := stt.RuntimeDir()
	parent := filepath.Dir(dir)
	if err := os.MkdirAll(parent, 0o755); err != nil {
		return err
	}
	staging, err := os.MkdirTemp(parent, ".venv-install-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(staging)
	if err := runRuntime(ctx, output, "python3", "-m", "venv", staging); err != nil {
		return fmt.Errorf("crear venv: %w", err)
	}
	python := runtimePython(staging)
	if info, err := os.Stat(python); err != nil || !info.Mode().IsRegular() {
		return fmt.Errorf("el venv no contiene un intérprete Python: %v", err)
	}

	provider, version := "cpu", sherpaVersion
	if _, err := runtimeRunner(ctx, nil, "nvidia-smi", "-L"); err == nil {
		if err := installWheel(ctx, output, python, "cuda"); err == nil {
			provider, version = "cuda", cudaVersion
		} else {
			if ctx.Err() != nil {
				return ctx.Err()
			}
			fmt.Fprintf(output, "CUDA no disponible (%v); instalando CPU\n", err)
			if err := installWheel(ctx, output, python, "cpu"); err != nil {
				return fmt.Errorf("instalar runtime CPU tras fallo de CUDA: %w", err)
			}
		}
	} else {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if err := installWheel(ctx, output, python, "cpu"); err != nil {
			return fmt.Errorf("instalar runtime CPU: %w", err)
		}
	}
	manifest, err := json.Marshal(runtimeManifest{Provider: provider, SherpaOnnx: version})
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(staging, manifestName), manifest, 0o644); err != nil {
		return err
	}
	return replaceRuntime(staging, dir)
}

func replaceRuntime(staging, dir string) error {
	_, err := os.Lstat(dir)
	if errors.Is(err, os.ErrNotExist) {
		return os.Rename(staging, dir)
	}
	if err != nil {
		return err
	}
	backup, err := os.MkdirTemp(filepath.Dir(dir), ".venv-backup-")
	if err != nil {
		return err
	}
	if err := os.Remove(backup); err != nil {
		return err
	}
	if err := os.Rename(dir, backup); err != nil {
		return err
	}
	if err := os.Rename(staging, dir); err != nil {
		if restoreErr := os.Rename(backup, dir); restoreErr != nil {
			return fmt.Errorf("activar runtime: %w; restaurar anterior: %v", err, restoreErr)
		}
		return err
	}
	return os.RemoveAll(backup)
}
