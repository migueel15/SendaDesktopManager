package control

import (
	"context"
	"errors"
	"io"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type failingShell struct{ calls []string }

func (s *failingShell) Call(_ context.Context, function string) (string, error) {
	s.calls = append(s.calls, function)
	return "", errors.New("shell desconectada")
}

func TestCancelResetsSubmapWhenShellFails(t *testing.T) {
	shell := &failingShell{}
	resets := 0
	submap := &resetStub{reset: func(context.Context) error {
		resets++
		return nil
	}}
	err := CancelAndReset(context.Background(), shell, submap)
	if err == nil || !strings.Contains(err.Error(), "shell desconectada") {
		t.Fatalf("CancelAndReset error = %v", err)
	}
	if !reflect.DeepEqual(shell.calls, []string{"cancel"}) {
		t.Fatalf("shell calls = %v", shell.calls)
	}
	if resets != 1 {
		t.Fatalf("Reset calls = %d, want 1", resets)
	}
}

func TestCheckMicrophoneRejectsMonitor(t *testing.T) {
	runner := func(_ context.Context, _ io.Reader, name string, _ ...string) ([]byte, error) {
		if name == "wpctl" {
			return []byte(`media.class = "Audio/Source" node.name = "alsa.monitor"`), nil
		}
		return []byte("alsa.monitor\n"), nil
	}
	if err := CheckMicrophone(context.Background(), runner); err == nil {
		t.Fatal("accepted monitor as microphone")
	}
}

func TestCheckMicrophoneAcceptsDefaultSource(t *testing.T) {
	runner := func(_ context.Context, _ io.Reader, name string, _ ...string) ([]byte, error) {
		if name != "wpctl" {
			t.Fatal("wpctl result should be sufficient")
		}
		return []byte(`media.class = "Audio/Source" node.name = "alsa_input.usb-mic"`), nil
	}
	if err := CheckMicrophone(context.Background(), runner); err != nil {
		t.Fatalf("CheckMicrophone = %v", err)
	}
}

type resetStub struct{ reset func(context.Context) error }

func (*resetStub) Enter(context.Context) error       { return stt.ErrSubmapUnavailable }
func (s *resetStub) Reset(ctx context.Context) error { return s.reset(ctx) }

func TestCancelResetSurvivesCancelledContextAndJoinsErrors(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	resetFailure := errors.New("reset failed")
	resets := 0
	submap := &resetStub{reset: func(ctx context.Context) error {
		resets++
		if ctx.Err() != nil {
			t.Fatalf("reset context = %v", ctx.Err())
		}
		if _, ok := ctx.Deadline(); !ok {
			t.Fatal("reset context has no timeout")
		}
		return resetFailure
	}}
	err := CancelAndReset(ctx, &failingShell{}, submap)
	if resets != 1 || !errors.Is(err, resetFailure) || !strings.Contains(err.Error(), "shell desconectada") {
		t.Fatalf("CancelAndReset = %v, Reset calls = %d", err, resets)
	}
}

func TestTogglePreloadChecksModelAndRuntime(t *testing.T) {
	for _, state := range []string{"idle", "preparing", "standby"} {
		for _, failure := range []error{ErrNoModel, ErrNoRuntime} {
			t.Run(state+"/"+failure.Error(), func(t *testing.T) {
				shell := &fakeShell{status: state}
				checks := okChecks()
				if failure == ErrNoModel {
					checks.ModelInstalled = func(string) bool { return false }
				} else {
					checks.RuntimeInstalled = func() bool { return false }
				}
				_, err := Toggle(context.Background(), shell, func() error { return Preflight(context.Background(), stt.LoadSettings(nil), checks) })
				if !errors.Is(err, failure) || shell.called("toggle") {
					t.Fatalf("Toggle = %v, calls = %v", err, shell.calls)
				}
			})
		}
	}
}
