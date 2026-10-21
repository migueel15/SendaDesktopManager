package setup

import (
	"bufio"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEnsureRuntimeInstalledSkipsPrompt(t *testing.T) {
	out := &strings.Builder{}
	called := false
	err := ensureRuntime(context.Background(), Options{
		Out: out, RuntimeInstalled: func() bool { return true },
		InstallRuntime: func(context.Context, io.Writer) error { called = true; return nil },
	}, bufio.NewReader(strings.NewReader("s\n")))
	if err != nil || called || strings.Contains(out.String(), "¿Instalar") {
		t.Fatalf("installed runtime: err=%v called=%t output=%q", err, called, out)
	}
}

func TestEnsureRuntimeDeclinedContinues(t *testing.T) {
	out := &strings.Builder{}
	called := false
	err := ensureRuntime(context.Background(), Options{
		Out: out, RuntimeInstalled: func() bool { return false },
		InstallRuntime: func(context.Context, io.Writer) error { called = true; return nil },
	}, bufio.NewReader(strings.NewReader("n\n")))
	if err != nil || called || !strings.Contains(out.String(), "El dictado no funcionará") {
		t.Fatalf("declined runtime: err=%v called=%t output=%q", err, called, out)
	}
}

func TestEnsureBindsPreservesExistingModule(t *testing.T) {
	path := filepath.Join(t.TempDir(), "senda_binds.lua")
	const original = "user changes\n"
	if err := os.WriteFile(path, []byte(original), 0o600); err != nil {
		t.Fatal(err)
	}
	out := &strings.Builder{}
	err := ensureBinds(context.Background(), Options{
		Out: out, BindsPath: func() string { return path },
		BindsLoaded: func(context.Context) (bool, error) { return false, nil },
	}, "/usr/bin/senda")
	if err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil || string(data) != original {
		t.Fatalf("existing module changed: %q, %v", data, err)
	}
	if !strings.Contains(out.String(), `require("modules.senda_binds")`) {
		t.Fatalf("missing require instruction: %q", out)
	}
}

func TestRunContinuesAfterRuntimeDeclined(t *testing.T) {
	home := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	osRelease := filepath.Join(home, "os-release")
	if err := os.WriteFile(osRelease, []byte("ID=arch\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	dataDir := filepath.Join(home, "data", "senda")
	if err := os.MkdirAll(filepath.Join(dataDir, "quickshell"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dataDir, "version"), []byte("v1.2.3\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	exe := filepath.Join(home, "senda")
	if err := os.WriteFile(exe, []byte("binary"), 0o755); err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"tag_name":"v1.2.3"}`)
	}))
	defer server.Close()
	installed, started := false, false
	out := &strings.Builder{}
	err := Run(context.Background(), Options{
		In: strings.NewReader("n\n"), Out: out,
		Getenv: envFunc(map[string]string{"XDG_CURRENT_DESKTOP": "Hyprland"}),
		Euid:   1000, OSReleasePath: osRelease,
		LookPath: lookPathFound(commandsExcept()...), Pacman: &fakePacman{present: packageOnly()},
		ReleaseAPI: server.URL, Executable: func() (string, error) { return exe, nil },
		RuntimeInstalled: func() bool { return false },
		InstallRuntime:   func(context.Context, io.Writer) error { installed = true; return nil },
		BindsPath:        func() string { return filepath.Join(home, "hypr", "modules", "senda_binds.lua") },
		BindsLoaded:      func(context.Context) (bool, error) { return false, nil },
		StartShell:       func(string) error { started = true; return nil },
	})
	if err != nil || installed || !started {
		t.Fatalf("Run after decline: err=%v installed=%t started=%t output=%q", err, installed, started, out)
	}
}
