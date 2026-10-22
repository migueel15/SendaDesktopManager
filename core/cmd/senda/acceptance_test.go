package main

import (
	"context"
	"errors"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/control"
	"github.com/spf13/cobra"
	"testing"
)

type f002CancelShell struct{ err error }

func (s f002CancelShell) Call(context.Context, string) (string, error) { return "", s.err }

func TestAC4F002CancelCommandAlwaysResets(t *testing.T) {
	for _, ipcErr := range []error{nil, errors.New("IPC unavailable"), context.Canceled} {
		submap := &commandSTTFakeSubmap{}
		cmd := newSTTCancelCmd(func(*cobra.Command) control.Shell { return f002CancelShell{ipcErr} }, func(*cobra.Command) stt.Submap { return submap })
		cmd.SetArgs(nil)
		if err := cmd.Execute(); !errors.Is(err, ipcErr) {
			t.Errorf("cancel = %v, want %v", err, ipcErr)
		}
		if submap.resets != 1 {
			t.Errorf("Reset calls = %d with IPC error %v", submap.resets, ipcErr)
		}
	}
}
