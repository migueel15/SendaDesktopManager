package engine

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestRuntimeInstall(t *testing.T) {
	for _, tc := range []struct {
		name, fail, provider string
		gpu                  bool
		wantCalls            []string
	}{
		{"cuda", "", "cuda", true, []string{"venv", "gpu", "pip-cuda", "import-cuda"}},
		{"cuda-pip-fails", "pip-cuda", "cpu", true, []string{"venv", "gpu", "pip-cuda", "pip-cpu", "import-cpu"}},
		{"cuda-import-fails", "import-cuda", "cpu", true, []string{"venv", "gpu", "pip-cuda", "import-cuda", "pip-cpu", "import-cpu"}},
		{"no-gpu", "", "cpu", false, []string{"venv", "gpu", "pip-cpu", "import-cpu"}},
		{"total-failure", "pip-cpu", "", true, []string{"venv", "gpu", "pip-cuda", "pip-cpu"}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			root := t.TempDir()
			t.Setenv("XDG_DATA_HOME", root)
			t.Setenv("SENDA_HOME", "")
			var calls []string
			lastWheel := ""
			runtimeRunner = func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
				var call string
				switch {
				case name == "python3" && reflect.DeepEqual(args[:2], []string{"-m", "venv"}):
					call = "venv"
					if err := os.MkdirAll(filepath.Join(args[2], "bin"), 0o755); err != nil {
						t.Fatal(err)
					}
					if err := os.WriteFile(runtimePython(args[2]), []byte("fake"), 0o755); err != nil {
						t.Fatal(err)
					}
				case name == "nvidia-smi" && reflect.DeepEqual(args, []string{"-L"}):
					call = "gpu"
					calls = append(calls, call)
					if tc.gpu {
						return []byte("GPU 0"), nil
					}
					return nil, errors.New("no GPU")
				case len(args) >= 4 && args[0] == "-m" && args[1] == "pip":
					if strings.Contains(strings.Join(args, " "), cudaVersion) {
						call, lastWheel = "pip-cuda", "cuda"
						if !strings.Contains(strings.Join(args, " "), "numpy") || !strings.Contains(strings.Join(args, " "), cudaWheelURL) {
							t.Fatal("missing CUDA dependency or wheel index")
						}
					} else {
						call, lastWheel = "pip-cpu", "cpu"
						if !strings.Contains(strings.Join(args, " "), "sherpa-onnx=="+sherpaVersion) {
							t.Fatal("wrong CPU version")
						}
					}
				case reflect.DeepEqual(args, []string{"-c", "import sherpa_onnx"}):
					call = "import-" + lastWheel
				default:
					t.Fatalf("unexpected command: %s %v", name, args)
				}
				calls = append(calls, call)
				if call == tc.fail || (tc.fail == "pip-cpu" && call == "pip-cuda") {
					return []byte("pip output"), errors.New("failure")
				}
				return []byte("pip output"), nil
			}
			t.Cleanup(func() { runtimeRunner = stt.ExecRunner })
			var output bytes.Buffer
			err := InstallRuntime(context.Background(), &output)
			if tc.provider == "" {
				if err == nil || RuntimeInstalled() || Python() != "" || RuntimeProvider() != "" {
					t.Fatalf("failed install = %v, installed=%v", err, RuntimeInstalled())
				}
			} else {
				if err != nil || !RuntimeInstalled() || RuntimeProvider() != tc.provider || Python() != runtimePython(stt.RuntimeDir()) {
					t.Fatalf("install = %v, installed=%v, provider=%q, python=%q", err, RuntimeInstalled(), RuntimeProvider(), Python())
				}
				var m runtimeManifest
				data, err := os.ReadFile(filepath.Join(stt.RuntimeDir(), manifestName))
				if err != nil || json.Unmarshal(data, &m) != nil || m.Provider != tc.provider {
					t.Fatalf("manifest = %s, %v", data, err)
				}
				wantVersion := sherpaVersion
				if tc.provider == "cuda" {
					wantVersion = cudaVersion
				}
				if m.SherpaOnnx != wantVersion {
					t.Fatalf("manifest version = %q", m.SherpaOnnx)
				}
			}
			if !reflect.DeepEqual(calls, tc.wantCalls) {
				t.Fatalf("calls = %v, want %v", calls, tc.wantCalls)
			}
			if !strings.Contains(output.String(), "pip output") {
				t.Fatalf("missing process output: %q", output.String())
			}
			entries, err := os.ReadDir(filepath.Dir(stt.RuntimeDir()))
			if err != nil {
				t.Fatal(err)
			}
			for _, entry := range entries {
				if strings.HasPrefix(entry.Name(), ".venv-") {
					t.Fatalf("left temporary directory %q", entry.Name())
				}
			}
		})
	}
}

func TestRuntimeInstallPreservesPreviousOnFailure(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_DATA_HOME", root)
	t.Setenv("SENDA_HOME", "")
	dir := stt.RuntimeDir()
	if err := os.MkdirAll(filepath.Join(dir, "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(runtimePython(dir), []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(runtimeManifest{Provider: "cpu", SherpaOnnx: sherpaVersion})
	if err := os.WriteFile(filepath.Join(dir, manifestName), data, 0o644); err != nil {
		t.Fatal(err)
	}
	runtimeRunner = func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		if name == "python3" {
			if err := os.MkdirAll(filepath.Join(args[2], "bin"), 0o755); err != nil {
				t.Fatal(err)
			}
			return nil, os.WriteFile(runtimePython(args[2]), []byte("new"), 0o755)
		}
		return nil, errors.New("offline")
	}
	t.Cleanup(func() { runtimeRunner = stt.ExecRunner })
	if err := InstallRuntime(context.Background(), nil); err == nil {
		t.Fatal("expected install failure")
	}
	if !RuntimeInstalled() || RuntimeProvider() != "cpu" {
		t.Fatal("previous runtime lost")
	}
	python, err := os.ReadFile(Python())
	if err != nil || string(python) != "old" {
		t.Fatalf("previous interpreter = %q, %v", python, err)
	}
}

func TestRuntimeInstalledRequiresManifestAndInterpreter(t *testing.T) {
	root := t.TempDir()
	t.Setenv("XDG_DATA_HOME", root)
	t.Setenv("SENDA_HOME", "")
	dir := stt.RuntimeDir()
	if err := os.MkdirAll(filepath.Join(dir, "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if RuntimeInstalled() {
		t.Fatal("accepted missing manifest")
	}
	for _, manifest := range []string{`{`, `{"provider":"cuda","sherpaOnnx":"1.13.8"}`, `{"provider":"cpu","sherpaOnnx":"1.13.8"}`} {
		if err := os.WriteFile(filepath.Join(dir, manifestName), []byte(manifest), 0o644); err != nil {
			t.Fatal(err)
		}
		if RuntimeInstalled() {
			t.Fatalf("accepted manifest without interpreter: %s", manifest)
		}
	}
	if err := os.WriteFile(runtimePython(dir), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if RuntimeInstalled() {
		t.Fatal("accepted non-executable interpreter")
	}
	if err := os.Chmod(runtimePython(dir), 0o755); err != nil {
		t.Fatal(err)
	}
	if !RuntimeInstalled() {
		t.Fatal("rejected complete runtime")
	}
}
