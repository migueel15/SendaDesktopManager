package control

import (
	"context"
	"errors"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func okChecks() Checks {
	return Checks{
		ModelInstalled:   func(string) bool { return true },
		RuntimeInstalled: func() bool { return true },
		Microphone:       func(context.Context) error { return nil },
	}
}

func TestAC8PreflightPassesWhenEverythingIsAvailable(t *testing.T) {
	if err := Preflight(context.Background(), stt.LoadSettings(nil), okChecks()); err != nil {
		t.Fatalf("Preflight = %v", err)
	}
}

func TestAC8PreflightErrors(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(*Checks)
		want   error
	}{
		{"no model", func(c *Checks) { c.ModelInstalled = func(string) bool { return false } }, ErrNoModel},
		{"no runtime", func(c *Checks) { c.RuntimeInstalled = func() bool { return false } }, ErrNoRuntime},
		{"no microphone", func(c *Checks) { c.Microphone = func(context.Context) error { return errors.New("sin entrada") } }, ErrNoMicrophone},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			checks := okChecks()
			tt.mutate(&checks)
			if err := Preflight(context.Background(), stt.LoadSettings(nil), checks); !errors.Is(err, tt.want) {
				t.Fatalf("Preflight = %v, want %v", err, tt.want)
			}
		})
	}
}

func TestAC8PreflightChecksActiveModel(t *testing.T) {
	var asked string
	checks := okChecks()
	checks.ModelInstalled = func(id string) bool { asked = id; return true }
	settings := stt.LoadSettings(map[string]string{stt.KeyModel: "other-model"})
	if err := Preflight(context.Background(), settings, checks); err != nil {
		t.Fatalf("Preflight = %v", err)
	}
	if asked != "other-model" {
		t.Fatalf("ModelInstalled asked for %q", asked)
	}
}

type fakeShell struct {
	status string
	calls  []string
}

func (f *fakeShell) Call(_ context.Context, function string) (string, error) {
	f.calls = append(f.calls, function)
	switch function {
	case "status":
		return f.status, nil
	case "toggle":
		return "started", nil
	}
	return "", nil
}

func (f *fakeShell) called(function string) bool {
	for _, c := range f.calls {
		if c == function {
			return true
		}
	}
	return false
}

func TestAC8ToggleIdleWithFailedPreflightDoesNotToggle(t *testing.T) {
	shell := &fakeShell{status: "idle"}
	_, err := Toggle(context.Background(), shell, func() error { return ErrNoModel })
	if !errors.Is(err, ErrNoModel) {
		t.Fatalf("Toggle error = %v, want ErrNoModel", err)
	}
	if shell.called("toggle") {
		t.Fatalf("toggle was called: %v", shell.calls)
	}
}

func TestAC8ToggleIdleWithPassingPreflightToggles(t *testing.T) {
	shell := &fakeShell{status: "idle"}
	if _, err := Toggle(context.Background(), shell, func() error { return nil }); err != nil {
		t.Fatalf("Toggle = %v", err)
	}
	if !shell.called("toggle") {
		t.Fatalf("toggle not called: %v", shell.calls)
	}
}

func TestAC8ToggleActiveStatesSkipPreflight(t *testing.T) {
	for _, state := range []string{"starting", "listening", "stopping"} {
		t.Run(state, func(t *testing.T) {
			shell := &fakeShell{status: state}
			preflight := false
			_, err := Toggle(context.Background(), shell, func() error { preflight = true; return ErrNoModel })
			if err != nil {
				t.Fatalf("Toggle = %v", err)
			}
			if preflight {
				t.Fatal("preflight ran")
			}
			if !shell.called("toggle") {
				t.Fatalf("toggle not called: %v", shell.calls)
			}
		})
	}
}
