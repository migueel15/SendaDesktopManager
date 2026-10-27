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

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
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

func TestActivityDoesNotReplaceTranscription(t *testing.T) {
	p := shellProcess(t, readyLine+`printf '%s\n' '{"event":"activity","active":true}' '{"event":"partial","text":"hola"}'; read cmd; printf '%s\n' '{"event":"final","text":"hola"}'`)
	select {
	case active := <-p.Activity():
		if !active {
			t.Fatal("activity not forwarded")
		}
	case <-time.After(time.Second):
		t.Fatal("activity not received")
	}
	select {
	case result := <-p.Results():
		if result.Text != "hola" {
			t.Fatalf("result = %q", result.Text)
		}
	case <-time.After(time.Second):
		t.Fatal("transcription not received")
	}
	if _, err := p.Stop(context.Background()); err != nil {
		t.Fatal(err)
	}
}

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
			waitRecorderReaped(t, pid)
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
	waitRecorderReaped(t, pid)
}

// SIGKILL can briefly leave a descendant in Linux's transient X (dead) state.
func waitRecorderReaped(t *testing.T, pid int) {
	t.Helper()
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

const loadedLine = `printf '%s\n' '{"event":"loaded"}'; `

func standbyProcess(t *testing.T, ctx context.Context, body string) *process {
	t.Helper()
	p, err := prepareProcess(ctx, exec.Command("sh", "-c", body))
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

func TestStandbyBeginAndStop(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	p := standbyProcess(t, ctx, loadedLine+`read cmd; test "$cmd" = start || exit 2; `+readyLine+`read cmd; test "$cmd" = stop || exit 3; printf '%s\n' '{"event":"final","text":"hola"}'; `+loadedLine+`read cmd; test "$cmd" = cancel`)
	select {
	case <-p.Loaded():
	case <-ctx.Done():
		t.Fatal(ctx.Err())
	}
	if p.Err() != nil {
		t.Fatal(p.Err())
	}
	p.mu.Lock()
	begun := p.current != nil
	p.mu.Unlock()
	if begun {
		t.Fatal("recording before Begin")
	}
	streams := make(chan stt.Stream, 8)
	var wg sync.WaitGroup
	for range 8 {
		wg.Go(func() {
			s, err := p.Begin(ctx)
			if err != nil || s == nil {
				t.Errorf("Begin = %v, %v", s, err)
			}
			streams <- s
		})
	}
	wg.Wait()
	stream := <-streams
	for range 7 {
		if other := <-streams; other != stream {
			t.Fatal("concurrent Begin returned distinct streams")
		}
	}
	if text, err := stream.Stop(ctx); text != "hola" || err != nil {
		t.Fatalf("Stop = %q, %v", text, err)
	}
}

func TestStandbyCancel(t *testing.T) {
	for _, loaded := range []bool{false, true} {
		t.Run(strconv.FormatBool(loaded), func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			body := `read cmd; test "$cmd" = cancel`
			if loaded {
				body = loadedLine + body
			}
			p := standbyProcess(t, ctx, body)
			if loaded {
				select {
				case <-p.Loaded():
				case <-ctx.Done():
					t.Fatal(ctx.Err())
				}
			}
			for range 2 {
				if err := p.Cancel(ctx); err != nil {
					t.Fatal(err)
				}
			}
			select {
			case <-p.Loaded():
			default:
				t.Fatal("Loaded remains open after cancellation")
			}
			if _, err := p.Begin(ctx); err == nil {
				t.Fatal("Begin accepted after Cancel")
			}
		})
	}
}

func TestStandbyLoadFailure(t *testing.T) {
	for _, body := range []string{`printf '%s\n' '{"event":"error","message":"modelo roto"}'`, `exit 23`, readyLine} {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		p := standbyProcess(t, ctx, body)
		select {
		case <-p.Loaded():
		case <-ctx.Done():
			t.Fatal(ctx.Err())
		}
		if p.Err() == nil {
			t.Fatal("load failure not published")
		}
		if _, err := p.Begin(ctx); err == nil {
			t.Fatal("Begin accepted failed load")
		}
		cancel()
	}
}

func TestStandbyCancellation(t *testing.T) {
	for _, phase := range []string{"preparing", "standby", "starting", "cancel-deadline"} {
		t.Run(phase, func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			body := `trap '' TERM; `
			if phase != "preparing" {
				body += loadedLine
			}
			p := standbyProcess(t, ctx, body+`sleep 30`)
			if phase != "preparing" {
				select {
				case <-p.Loaded():
				case <-time.After(time.Second):
					t.Fatal("load timeout")
				}
			}
			if phase == "starting" || phase == "cancel-deadline" {
				limit, stop := context.WithTimeout(ctx, 30*time.Millisecond)
				defer stop()
				var err error
				if phase == "starting" {
					_, err = p.Begin(limit)
				} else {
					err = p.Cancel(limit)
				}
				if !errors.Is(err, context.DeadlineExceeded) {
					t.Fatal(err)
				}
			} else {
				cancel()
			}
			select {
			case <-p.done:
			case <-time.After(time.Second):
				t.Fatal("process did not terminate")
			}
			if err := syscall.Kill(p.cmd.Process.Pid, 0); !errors.Is(err, syscall.ESRCH) {
				t.Fatalf("parent alive: %v", err)
			}
		})
	}
}

// Completed handles must remain tied to their dictation, even when the next one fails.
func TestResidentStreamIsolation(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	p := standbyProcess(t, ctx, loadedLine+`read cmd; test "$cmd" = start || exit 2; `+readyLine+
		`read cmd; test "$cmd" = stop || exit 3; printf '%s\n' '{"event":"final","text":"primero"}'; `+loadedLine+
		`read cmd; test "$cmd" = start || exit 4; `+readyLine+
		`read cmd; test "$cmd" = stop || exit 5; printf '%s\n' '{"event":"error","message":"micrófono roto"}'; exit 1`)
	first, err := p.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if text, err := first.Stop(ctx); text != "primero" || err != nil {
		t.Fatalf("first Stop = %q, %v", text, err)
	}
	second, err := p.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if first == second || first.Results() == second.Results() {
		t.Fatal("dictations share a stream")
	}
	if text, err := first.Stop(ctx); text != "primero" || err != nil {
		t.Fatalf("repeated Stop = %q, %v", text, err)
	}
	if err := first.Cancel(ctx); err != nil {
		t.Fatal(err)
	}
	if _, err := second.Stop(ctx); err == nil || !strings.Contains(err.Error(), "micrófono roto") {
		t.Fatalf("second Stop = %v", err)
	}
	if first.Err() != nil || second.Err() == nil {
		t.Fatalf("dictation errors = %v, %v", first.Err(), second.Err())
	}
}

func TestResidentStreamStopDeadline(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	p := standbyProcess(t, ctx, `trap '' TERM; `+loadedLine+`read cmd; `+readyLine+`sleep 30`)
	stream, err := p.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	limit, stop := context.WithTimeout(ctx, 30*time.Millisecond)
	defer stop()
	if _, err := stream.Stop(limit); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal(err)
	}
	select {
	case <-p.done:
	default:
		t.Fatal("process not reaped")
	}
	if !errors.Is(stream.Err(), context.DeadlineExceeded) {
		t.Fatal(stream.Err())
	}
}
