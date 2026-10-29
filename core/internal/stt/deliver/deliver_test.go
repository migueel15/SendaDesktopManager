package deliver

import (
	"bytes"
	"context"
	"errors"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestClipboardFailureStopsDelivery(t *testing.T) {
	failure := errors.New("clipboard unavailable")
	var calls []string
	run := func(_ context.Context, _ io.Reader, name string, _ ...string) ([]byte, error) {
		calls = append(calls, name)
		return nil, failure
	}
	err := New(run).Deliver(context.Background(), "hola", settings(stt.PasteDirect))
	if !errors.Is(err, failure) || !strings.Contains(err.Error(), "copia") {
		t.Fatalf("Deliver error = %v", err)
	}
	if len(calls) != 1 || calls[0] != "wl-copy" {
		t.Fatalf("commands after failed copy: %v", calls)
	}
}

func TestInvalidActiveWindowFallsBackAndTracesSteps(t *testing.T) {
	var traces bytes.Buffer
	previous := log.Writer()
	log.SetOutput(&traces)
	t.Cleanup(func() { log.SetOutput(previous) })
	var pasteArgs []string
	run := func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		if name == "hyprctl" && args[0] == "dispatch" {
			pasteArgs = args
			return []byte("ok"), nil
		}
		if name == "hyprctl" {
			return []byte("invalid json"), nil
		}
		return nil, nil
	}
	if err := New(run).Deliver(context.Background(), "texto privado", settings(stt.PasteDirect)); err != nil {
		t.Fatal(err)
	}
	if !slicesEqual(pasteArgs, []string{"dispatch", "hl.dsp.send_shortcut({mods = \"CTRL\", key = \"V\"})"}) {
		t.Fatalf("paste args = %v", pasteArgs)
	}
	for _, step := range []string{"copia", "ventana activa", "pegado"} {
		for _, phase := range []string{"inicio", "fin"} {
			if !strings.Contains(traces.String(), step+": "+phase) {
				t.Errorf("missing %s %s trace: %s", step, phase, traces.String())
			}
		}
	}
	if !strings.Contains(traces.String(), "ventana activa: hyprctl -j activewindow: respuesta inválida") || strings.Contains(traces.String(), "texto privado") {
		t.Fatalf("unexpected traces: %s", traces.String())
	}
}

func TestDetachedRunnerReportsCommandFailure(t *testing.T) {
	for _, command := range []string{"exit 7", "command-that-does-not-exist-senda"} {
		if _, err := stt.DetachedRunner(context.Background(), nil, "sh", "-c", command); err == nil {
			t.Fatalf("DetachedRunner(%q) succeeded", command)
		}
	}
}

func TestDetachedRunnerHonorsCancellation(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	started := time.Now()
	if _, err := stt.DetachedRunner(ctx, nil, "sleep", "10"); err == nil {
		t.Fatal("cancelled command succeeded")
	}
	if elapsed := time.Since(started); elapsed > time.Second {
		t.Fatalf("cancellation took %s", elapsed)
	}
}

func TestProductionRunnerCapturesActiveWindow(t *testing.T) {
	dir := t.TempDir()
	argsPath := filepath.Join(dir, "paste-args")
	for name, body := range map[string]string{
		"wl-copy": "cat >/dev/null",
		"hyprctl": `if [ "$1" = dispatch ]; then printf '%s\n' "$@" > "$SENDA_TEST_PASTE_ARGS"; echo ok; else printf '%s' '{"class":"kitty"}'; fi`,
	} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("#!/bin/sh\n"+body+"\n"), 0700); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("SENDA_TEST_PASTE_ARGS", argsPath)
	if err := New(stt.ExecRunner).Deliver(context.Background(), "hola", settings(stt.PasteDirect)); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(argsPath)
	if err != nil || string(data) != "dispatch\nhl.dsp.send_shortcut({mods = \"CTRL SHIFT\", key = \"V\"})\n" {
		t.Fatalf("paste args = %q, %v", data, err)
	}
}

func TestHyprctlFailureFallsBackToCtrlV(t *testing.T) {
	var calls []call
	run := func(_ context.Context, stdin io.Reader, name string, args ...string) ([]byte, error) {
		c := call{name: name, args: args}
		if stdin != nil {
			b, _ := io.ReadAll(stdin)
			c.stdin = string(b)
		}
		calls = append(calls, c)
		if name == "hyprctl" && args[0] != "dispatch" {
			return nil, errors.New("hyprctl unavailable")
		}
		if name == "hyprctl" {
			return []byte("ok"), nil
		}
		return nil, nil
	}

	if err := New(run).Deliver(context.Background(), "hola", settings(stt.PasteDirect)); err != nil {
		t.Fatalf("Deliver = %v", err)
	}
	if len(calls) != 3 || calls[2].name != "hyprctl" || !slicesEqual(calls[2].args, []string{"dispatch", "hl.dsp.send_shortcut({mods = \"CTRL\", key = \"V\"})"}) {
		t.Fatalf("calls = %+v", calls)
	}
}

func TestPasteFailureReportsClipboardFallback(t *testing.T) {
	run := func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		if name == "hyprctl" && args[0] == "dispatch" {
			return []byte("error: invalid dispatcher"), nil
		}
		if name == "hyprctl" {
			return []byte(`{"class":"firefox"}`), nil
		}
		return nil, nil
	}

	err := New(run).Deliver(context.Background(), "hola", settings(stt.PasteDirect))
	if err == nil || !strings.Contains(err.Error(), "permanece en el portapapeles") || !strings.Contains(err.Error(), "invalid dispatcher") {
		t.Fatalf("Deliver error = %v", err)
	}
}

func slicesEqual(got, want []string) bool {
	if len(got) != len(want) {
		return false
	}
	for i := range got {
		if got[i] != want[i] {
			return false
		}
	}
	return true
}
