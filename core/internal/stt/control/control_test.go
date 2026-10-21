package control

import (
	"context"
	"errors"
	"io"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
)

type failingShell struct{ calls []string }

func (s *failingShell) Call(_ context.Context, function string) (string, error) {
	s.calls = append(s.calls, function)
	return "", errors.New("shell desconectada")
}

func TestCancelResetsSubmapWhenShellFails(t *testing.T) {
	shell := &failingShell{}
	var got []string
	runner := func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		got = append([]string{name}, args...)
		return []byte("ok\n"), nil
	}
	err := CancelAndReset(context.Background(), shell, binds.NewSubmap(runner))
	if err == nil || !strings.Contains(err.Error(), "shell desconectada") {
		t.Fatalf("CancelAndReset error = %v", err)
	}
	if !reflect.DeepEqual(shell.calls, []string{"cancel"}) {
		t.Fatalf("shell calls = %v", shell.calls)
	}
	want := []string{"hyprctl", "dispatch", `hl.dsp.submap("reset")`}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("reset command = %v, want %v", got, want)
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
