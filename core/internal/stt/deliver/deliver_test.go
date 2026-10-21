package deliver

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestHyprctlFailureFallsBackToCtrlV(t *testing.T) {
	var calls []call
	run := func(_ context.Context, stdin io.Reader, name string, args ...string) ([]byte, error) {
		c := call{name: name, args: args}
		if stdin != nil {
			b, _ := io.ReadAll(stdin)
			c.stdin = string(b)
		}
		calls = append(calls, c)
		if name == "hyprctl" {
			return nil, errors.New("hyprctl unavailable")
		}
		return nil, nil
	}

	if err := New(run).Deliver(context.Background(), "hola", settings(stt.PasteDirect)); err != nil {
		t.Fatalf("Deliver = %v", err)
	}
	if len(calls) != 3 || calls[2].name != "wtype" || !slicesEqual(calls[2].args, []string{"-M", "ctrl", "v", "-m", "ctrl"}) {
		t.Fatalf("calls = %+v", calls)
	}
}

func TestWtypeFailureReportsClipboardFallback(t *testing.T) {
	run := func(_ context.Context, _ io.Reader, name string, _ ...string) ([]byte, error) {
		if name == "wtype" {
			return nil, errors.New("wtype unavailable")
		}
		if name == "hyprctl" {
			return []byte(`{"class":"firefox"}`), nil
		}
		return nil, nil
	}

	err := New(run).Deliver(context.Background(), "hola", settings(stt.PasteDirect))
	if err == nil || !strings.Contains(err.Error(), "permanece en el portapapeles") || !strings.Contains(err.Error(), "wtype unavailable") {
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
