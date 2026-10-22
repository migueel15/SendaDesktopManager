package main

import (
	"bytes"
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/control"
	"github.com/spf13/cobra"
)

type commandSTTFakeShell struct {
	status string
	calls  []string
}

func (s *commandSTTFakeShell) Call(_ context.Context, function string) (string, error) {
	s.calls = append(s.calls, function)
	if function == "status" {
		return s.status, nil
	}
	return "ok", nil
}

type commandSTTFakeNotifier struct {
	calls   int
	summary string
	body    string
}

func (n *commandSTTFakeNotifier) Notify(_ context.Context, summary, body string) error {
	n.calls++
	n.summary = summary
	n.body = body
	return nil
}

type commandSTTFakeSubmap struct{ resets int }

func (*commandSTTFakeSubmap) Enter(context.Context) error { return nil }
func (s *commandSTTFakeSubmap) Reset(context.Context) error {
	s.resets++
	return nil
}

func TestSTTCommandHelpAndArgs(t *testing.T) {
	cmd := sttCmd()
	var output bytes.Buffer
	cmd.SetOut(&output)
	cmd.SetArgs([]string{"--help"})
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"toggle", "cancel", "status", "session", "models", "shortcut", "runtime"} {
		if !strings.Contains(output.String(), name) {
			t.Errorf("help is missing %s", name)
		}
	}
	for _, args := range [][]string{{"toggle", "extra"}, {"models", "install"}, {"shortcut", "set"}, {"runtime", "install", "extra"}} {
		cmd := sttCmd()
		cmd.SetOut(&output)
		cmd.SetErr(&output)
		cmd.SetArgs(args)
		if err := cmd.Execute(); err == nil {
			t.Fatalf("accepted invalid args %v: %v", args, err)
		}
	}
}

func TestSTTToggleCommandCallsToggleIPC(t *testing.T) {
	shell := &commandSTTFakeShell{status: "idle"}
	notifier := &commandSTTFakeNotifier{}
	preflightCalled := false
	cmd := newSTTToggleCmd(func(*cobra.Command) control.Shell { return shell }, func(*cobra.Command) error {
		preflightCalled = true
		return nil
	}, notifier)
	cmd.SetArgs(nil)

	if err := cmd.Execute(); err != nil {
		t.Fatalf("toggle command = %v", err)
	}
	if !preflightCalled {
		t.Fatal("toggle command did not run preflight while idle")
	}
	if !reflect.DeepEqual(shell.calls, []string{"status", "toggle"}) {
		t.Fatalf("IPC calls = %v, want [status toggle]", shell.calls)
	}
	if notifier.calls != 0 {
		t.Fatalf("notifications = %d, want 0", notifier.calls)
	}
}

func TestSTTToggleCommandNotifiesForAnyPreflightError(t *testing.T) {
	shell := &commandSTTFakeShell{status: "idle"}
	notifier := &commandSTTFakeNotifier{}
	const message = "No se pudo leer la configuración del dictado: permiso denegado"
	cmd := newSTTToggleCmd(func(*cobra.Command) control.Shell { return shell }, func(*cobra.Command) error {
		return errors.New(message)
	}, notifier)
	var stderr bytes.Buffer
	cmd.SetErr(&stderr)
	cmd.SetArgs(nil)

	err := cmd.Execute()
	if err == nil || !strings.Contains(err.Error(), message) {
		t.Fatalf("toggle error = %v, want %q", err, message)
	}
	if notifier.calls != 1 || notifier.summary != "Dictado no disponible" || notifier.body != message {
		t.Fatalf("notification = (%d, %q, %q)", notifier.calls, notifier.summary, notifier.body)
	}
	if !strings.Contains(stderr.String(), message) {
		t.Fatalf("stderr = %q, want the preflight message", stderr.String())
	}
	if !reflect.DeepEqual(shell.calls, []string{"status"}) {
		t.Fatalf("IPC calls = %v, want only [status]", shell.calls)
	}
}

func TestSTTCancelCommandCallsCancelIPC(t *testing.T) {
	shell := &commandSTTFakeShell{}
	submap := &commandSTTFakeSubmap{}
	cmd := newSTTCancelCmd(func(*cobra.Command) control.Shell { return shell }, func(*cobra.Command) stt.Submap { return submap })
	cmd.SetArgs(nil)

	if err := cmd.Execute(); err != nil {
		t.Fatalf("cancel command = %v", err)
	}
	if !reflect.DeepEqual(shell.calls, []string{"cancel"}) {
		t.Fatalf("IPC calls = %v, want [cancel]", shell.calls)
	}
	if submap.resets != 1 {
		t.Fatalf("submap resets = %d, want 1", submap.resets)
	}
}

func TestSTTTogglePreloadFailureNotifiesWithoutToggling(t *testing.T) {
	for _, state := range []string{"preparing", "standby"} {
		t.Run(state, func(t *testing.T) {
			shell := &commandSTTFakeShell{status: state}
			notifier := &commandSTTFakeNotifier{}
			cmd := newSTTToggleCmd(func(*cobra.Command) control.Shell { return shell }, func(*cobra.Command) error { return control.ErrNoMicrophone }, notifier)
			cmd.SetOut(&bytes.Buffer{})
			cmd.SetErr(&bytes.Buffer{})
			cmd.SetArgs(nil)
			if err := cmd.Execute(); !errors.Is(err, control.ErrNoMicrophone) {
				t.Fatalf("toggle error = %v", err)
			}
			if !reflect.DeepEqual(shell.calls, []string{"status"}) {
				t.Fatalf("IPC calls = %v", shell.calls)
			}
			if notifier.calls != 1 || notifier.body != control.ErrNoMicrophone.Error() {
				t.Fatalf("notification = %+v", notifier)
			}
		})
	}
}
