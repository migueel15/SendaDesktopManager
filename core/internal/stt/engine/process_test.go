package engine

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"
)

func shellProcess(t *testing.T, body string) *process {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	t.Cleanup(cancel)
	p, err := startProcess(ctx, exec.Command("sh", "-c", body))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = p.Cancel(ctx)
	})
	return p
}

const readyLine = `printf '%s\n' '{"event":"ready"}'; `

func TestStopReturnsFinalAndClosesResults(t *testing.T) {
	p := shellProcess(t, readyLine+`printf '%s\n' '{"event":"partial","text":"hola"}'; read cmd; test "$cmd" = stop || exit 2; printf '%s\n' '{"event":"final","text":"hola mundo"}'`)
	select {
	case result := <-p.Results():
		if result.Text != "hola" {
			t.Fatal(result)
		}
	case <-time.After(time.Second):
		t.Fatal("no partial")
	}
	for range 2 {
		text, err := p.Stop(context.Background())
		if err != nil || text != "hola mundo" {
			t.Fatalf("%q, %v", text, err)
		}
	}
	var last string
	for result := range p.Results() {
		last = result.Text
	}
	if last != "hola mundo" || p.Err() != nil {
		t.Fatalf("%q, %v", last, p.Err())
	}
}

func TestProcessErrors(t *testing.T) {
	for _, tt := range []struct {
		name, body, want string
		ready            bool
	}{
		{"before-ready", `printf '%s\n' '{"event":"error","message":"modelo roto"}'`, "modelo roto", false},
		{"no-ready", `exit 0`, "inesperadamente", false},
		{"bad-json", readyLine + `printf 'broken\n'`, "Respuesta no válida", true},
		{"audio", readyLine + `printf '%s\n' '{"event":"error","message":"No se pudo abrir el micrófono: dispositivo ausente"}'`, "micrófono", true},
		{"died", readyLine + `exit 23`, "inesperadamente", true},
		{"no-final", readyLine + `read cmd; exit 0`, "inesperadamente", true},
		{"bad-order", `printf '%s\n' '{"event":"partial","text":"hola"}'`, "Secuencia no válida", false},
	} {
		t.Run(tt.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), time.Second)
			defer cancel()
			p, err := startProcess(ctx, exec.Command("sh", "-c", tt.body))
			if err == nil {
				if !tt.ready {
					t.Fatal("unexpected ready")
				}
				if tt.name == "no-final" {
					_, _ = p.Stop(ctx)
				}
				for range p.Results() {
				}
				err = p.Err()
			}
			if err == nil || !strings.Contains(err.Error(), tt.want) {
				t.Fatalf("want %q, got %v", tt.want, err)
			}
		})
	}
}

func TestCancelConcurrentAndIdempotent(t *testing.T) {
	p := shellProcess(t, readyLine+`read cmd; test "$cmd" = cancel`)
	var wg sync.WaitGroup
	for range 12 {
		wg.Go(func() {
			if err := p.Cancel(context.Background()); err != nil {
				t.Error(err)
			}
		})
	}
	wg.Wait()
	for range p.Results() {
	}
	if p.Err() != nil {
		t.Fatal(p.Err())
	}
}

func TestDeadlinesKillProcessGroup(t *testing.T) {
	for _, command := range []string{"stop", "cancel"} {
		t.Run(command, func(t *testing.T) {
			pidFile := filepath.Join(t.TempDir(), "child-pid")
			body := fmt.Sprintf(`trap '' TERM; sleep 30 & child=$!; echo $child > %q; `, pidFile) + readyLine + `wait`
			p := shellProcess(t, body)
			ctx, cancel := context.WithTimeout(context.Background(), 40*time.Millisecond)
			defer cancel()
			start := time.Now()
			_, err := p.finish(ctx, command)
			if !errors.Is(err, context.DeadlineExceeded) || time.Since(start) > time.Second {
				t.Fatalf("%v, %v", err, time.Since(start))
			}
			if err := syscall.Kill(p.cmd.Process.Pid, 0); !errors.Is(err, syscall.ESRCH) {
				t.Fatalf("parent alive: %v", err)
			}
			data, err := os.ReadFile(pidFile)
			if err != nil {
				t.Fatal(err)
			}
			pid, _ := strconv.Atoi(strings.TrimSpace(string(data)))
			// A killed descendant may briefly remain a zombie until init reaps it.
			stat, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
			if err == nil && !strings.Contains(string(stat), ") Z ") {
				t.Fatalf("recorder still running: %s", stat)
			}
		})
	}
}

func TestStartDeadlineAndCancellation(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Millisecond)
	defer cancel()
	if _, err := startProcess(ctx, exec.Command("sh", "-c", `trap '' TERM; sleep 30`)); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal(err)
	}
	ctx2, cancel2 := context.WithCancel(context.Background())
	p, err := startProcess(ctx2, exec.Command("sh", "-c", readyLine+`sleep 30`))
	if err != nil {
		t.Fatal(err)
	}
	cancel2()
	for range p.Results() {
	}
	if !errors.Is(p.Err(), context.Canceled) {
		t.Fatal(p.Err())
	}
}

func TestUnexpectedDeathKillsRecorder(t *testing.T) {
	pidFile := filepath.Join(t.TempDir(), "child-pid")
	body := fmt.Sprintf(`sleep 30 >/dev/null 2>&1 & echo $! > %q; `, pidFile) + readyLine + `read cmd; exit 23`
	p := shellProcess(t, body)
	if _, err := p.Stop(context.Background()); err == nil {
		t.Fatal("unexpected death was accepted")
	}
	data, err := os.ReadFile(pidFile)
	if err != nil {
		t.Fatal(err)
	}
	pid, _ := strconv.Atoi(strings.TrimSpace(string(data)))
	deadline := time.Now().Add(time.Second)
	for {
		stat, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
		if err != nil || strings.Contains(string(stat), ") Z ") {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("orphan recorder: %s", stat)
		}
		time.Sleep(time.Millisecond)
	}
}
