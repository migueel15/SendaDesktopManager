// Package engine adapts the isolated Python recognizer and manages its runtime.
package engine

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

//go:embed stt_engine.py
var script []byte

type engine struct{ python string }

func New() stt.Engine { return &engine{} }

// Prepare reserves the standby protocol; loading is implemented separately.
func (e *engine) Prepare(ctx context.Context, opts stt.EngineOptions) (stt.Standby, error) {
	return nil, stt.ErrNotImplemented
}

func (e *engine) Start(ctx context.Context, opts stt.EngineOptions) (stt.Stream, error) {
	m, err := stt.ReadManifest(opts.ModelDir)
	if err != nil {
		return nil, fmt.Errorf("No se pudo leer el modelo: %w", err)
	}
	if m.Kind != "transducer" || m.Encoder == "" || m.Decoder == "" || m.Joiner == "" || m.Tokens == "" {
		return nil, fmt.Errorf("El manifiesto del modelo no contiene un transductor completo")
	}
	python := e.python
	if python == "" {
		python = Python()
	}
	if python == "" {
		return nil, fmt.Errorf("El entorno de reconocimiento de voz no está instalado")
	}
	provider := opts.Provider
	if provider == "" || provider == "auto" {
		provider = RuntimeProvider()
		if provider == "" {
			provider = "cpu"
		}
	}
	if provider != "cpu" && provider != "cuda" {
		return nil, fmt.Errorf("Proveedor de reconocimiento no válido: %s", provider)
	}
	path, err := writeScript(filepath.Dir(filepath.Dir(python)))
	if err != nil {
		return nil, fmt.Errorf("No se pudo preparar el motor de voz: %w", err)
	}
	manifest, _ := json.Marshal(m)
	return startProcess(ctx, exec.Command(python, "-u", path, "--model-dir", opts.ModelDir,
		"--manifest", string(manifest), "--provider", provider, "--language", opts.Language))
}

func writeScript(dir string) (string, error) {
	path := filepath.Join(dir, "stt-engine.py")
	if data, err := os.ReadFile(path); err == nil && bytes.Equal(data, script) {
		return path, nil
	}
	f, err := os.CreateTemp(dir, ".stt-engine-*")
	if err != nil {
		return "", err
	}
	defer os.Remove(f.Name())
	if _, err = f.Write(script); err != nil {
		f.Close()
		return "", err
	}
	if err = f.Close(); err == nil {
		err = os.Rename(f.Name(), path)
	}
	return path, err
}
