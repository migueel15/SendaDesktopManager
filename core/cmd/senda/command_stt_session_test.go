package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"slices"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/session"
)

type signalEngine struct{}

func (signalEngine) Prepare(context.Context, stt.EngineOptions) (stt.Standby, error) {
	return nil, stt.ErrNotImplemented
}

func (signalEngine) Start(context.Context, stt.EngineOptions) (stt.Stream, error) {
	return &signalStream{results: make(chan stt.Result)}, nil
}

type signalStream struct{ results chan stt.Result }

func (s *signalStream) Results() <-chan stt.Result         { return s.results }
func (*signalStream) Err() error                           { return nil }
func (*signalStream) Stop(context.Context) (string, error) { panic("unexpected stop") }
func (*signalStream) Cancel(ctx context.Context) error {
	if ctx.Err() != nil {
		return fmt.Errorf("cancel context is dead")
	}
	if _, ok := ctx.Deadline(); !ok {
		return fmt.Errorf("cancel has no deadline")
	}
	fmt.Fprintln(os.Stderr, "cancel-live")
	return nil
}

type signalSubmap struct{}

func (signalSubmap) Enter(context.Context) error { return nil }
func (signalSubmap) Reset(ctx context.Context) error {
	if ctx.Err() != nil {
		return fmt.Errorf("reset context is dead")
	}
	if _, ok := ctx.Deadline(); !ok {
		return fmt.Errorf("reset has no deadline")
	}
	fmt.Fprintln(os.Stderr, "reset-live")
	return nil
}

type signalDeliverer struct{}

func (signalDeliverer) Deliver(context.Context, string, stt.Settings) error {
	panic("unexpected delivery")
}

func TestSTTSessionSignalHelper(t *testing.T) {
	if os.Getenv("SENDA_STT_SIGNAL_HELPER") != "1" {
		return
	}
	cmd := newSTTSessionCmd(func() (session.Deps, error) {
		return session.Deps{Engine: signalEngine{}, Deliverer: signalDeliverer{}, Submap: signalSubmap{}, Settings: stt.LoadSettings(nil)}, nil
	})
	cmd.SetIn(os.Stdin)
	cmd.SetOut(os.Stdout)
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
}

func TestSTTSessionSIGTERM(t *testing.T) {
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	child := exec.CommandContext(ctx, exe, "-test.run=^TestSTTSessionSignalHelper$")
	child.Env = append(os.Environ(), "SENDA_STT_SIGNAL_HELPER=1")
	stdin, err := child.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	defer stdin.Close()
	stdout, err := child.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	var stderr bytes.Buffer
	child.Stderr = &stderr
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	defer child.Process.Kill()
	sc := bufio.NewScanner(stdout)
	if !sc.Scan() {
		t.Fatal("missing ready")
	}
	var event stt.Event
	if err := json.Unmarshal(sc.Bytes(), &event); err != nil || event.Type != stt.EventReady {
		t.Fatalf("ready = %q (%v)", sc.Text(), err)
	}
	if err := child.Process.Signal(syscall.SIGTERM); err != nil {
		t.Fatal(err)
	}
	events := []stt.EventType{event.Type}
	for sc.Scan() {
		if err := json.Unmarshal(sc.Bytes(), &event); err == nil {
			events = append(events, event.Type)
		}
	}
	if err := child.Wait(); err != nil {
		t.Fatalf("signal exit: %v; %s", err, stderr.String())
	}
	if !slices.Equal(events, []stt.EventType{stt.EventReady, stt.EventCancelled}) {
		t.Fatalf("events = %v", events)
	}
	for _, marker := range []string{"cancel-live", "reset-live"} {
		if !strings.Contains(stderr.String(), marker) {
			t.Fatalf("missing %s: %s", marker, stderr.String())
		}
	}
}

type cliStandbyEngine struct{ signalEngine }

func (cliStandbyEngine) Prepare(context.Context, stt.EngineOptions) (stt.Standby, error) {
	loaded := make(chan struct{})
	close(loaded)
	return cliStandby{loaded}, nil
}

type cliStandby struct{ loaded chan struct{} }

func (s cliStandby) Loaded() <-chan struct{}                 { return s.loaded }
func (cliStandby) Err() error                                { return nil }
func (cliStandby) Begin(context.Context) (stt.Stream, error) { panic("unexpected Begin") }
func (cliStandby) Cancel(ctx context.Context) error          { return ctx.Err() }

func TestSTTSessionStandbyFlag(t *testing.T) {
	cmd := newSTTSessionCmd(func() (session.Deps, error) {
		return session.Deps{Engine: cliStandbyEngine{}, Deliverer: signalDeliverer{}, Submap: signalSubmap{}}, nil
	})
	cmd.SetArgs([]string{"--standby"})
	cmd.SetIn(strings.NewReader("cancel\n"))
	var out bytes.Buffer
	cmd.SetOut(&out)
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out.String(), `"event":"cancelled"`) || strings.Contains(out.String(), `"event":"ready"`) {
		t.Fatalf("events = %s", out.String())
	}
}
