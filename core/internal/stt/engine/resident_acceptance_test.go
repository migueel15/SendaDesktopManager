package engine

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// This process double implements the resident wire protocol independently of
// exercise.py. The log proves both dictations use one launch and distinct starts.
func TestAC7F002ResidentProcess(t *testing.T) {
	for _, first := range []string{stt.CommandStop, stt.CommandCancel} {
		t.Run(first, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			log := filepath.Join(t.TempDir(), "commands")
			body := fmt.Sprintf(`
exec 3> %q
printf 'launch\n' >&3
n=0
wait_gate() {
    printf 'waiting-%%s\n' "$1" >&3
    while [ ! -f %q/"$1" ]; do sleep 0.01; done
    printf '%%s\n' "$1" >&3
}
wait_gate loaded-1
printf '%%s\n' '{"event":"loaded"}'
while read command; do
    printf '%%s\n' "$command" >&3
    case "$command" in
        stop|cancel) exit 0 ;;
        start) ;;
        *) exit 2 ;;
    esac
    n=$((n+1))
    wait_gate ready-"$n"
    printf '%%s\n' '{"event":"ready"}'
    read command || exit 3
    printf '%%s\n' "$command" >&3
    case "$command" in
        stop) printf '{"event":"final","text":"dictation-%%s"}\n' "$n" ;;
        cancel) ;;
        *) exit 4 ;;
    esac
    wait_gate loaded-$((n+1))
    printf '%%s\n' '{"event":"loaded"}'
done
`, log, filepath.Dir(log))
			p, err := prepareProcess(ctx, exec.Command("sh", "-c", body))
			if err != nil {
				t.Fatal(err)
			}
			defer func() {
				cancel()
				select {
				case <-p.done:
				case <-time.After(time.Second):
					t.Error("resident process was not reaped")
				}
			}()
			var standby stt.Standby = p
			var previous <-chan struct{}
			for cycle := 1; cycle <= 3; cycle++ {
				loaded := standby.Loaded()
				if loaded == previous {
					t.Fatalf("Loaded not rearmed for cycle %d", cycle)
				}
				previous = loaded
				loadEvent := fmt.Sprintf("loaded-%d", cycle)
				waitResidentLog(t, ctx, log, "waiting-"+loadEvent)
				select {
				case <-loaded:
					t.Fatalf("Loaded cycle %d closed before its loaded event", cycle)
				default:
				}
				type begun struct {
					stream stt.Stream
					err    error
				}
				result := make(chan begun, 1)
				if cycle <= 2 {
					go func() { stream, err := standby.Begin(ctx); result <- begun{stream, err} }()
					select {
					case r := <-result:
						t.Fatalf("Begin cycle %d returned before loaded: %v", cycle, r.err)
					case <-time.After(30 * time.Millisecond):
					}
					data, err := os.ReadFile(log)
					if err != nil || strings.Count(string(data), "start\n") != cycle-1 {
						t.Fatalf("Begin sent start before loaded cycle %d: %q, %v", cycle, data, err)
					}
				}
				releaseResidentGate(t, log, loadEvent)
				select {
				case <-loaded:
				case <-ctx.Done():
					t.Fatal("next loaded event missing:", ctx.Err())
				}
				assertResidentLog(t, log, loadEvent)
				if cycle == 3 {
					break
				}
				readyEvent := fmt.Sprintf("ready-%d", cycle)
				waitResidentLog(t, ctx, log, "waiting-"+readyEvent)
				select {
				case r := <-result:
					t.Fatalf("Begin cycle %d returned before ready: %v", cycle, r.err)
				case <-time.After(30 * time.Millisecond):
				}
				releaseResidentGate(t, log, readyEvent)
				var stream stt.Stream
				select {
				case r := <-result:
					if r.err != nil {
						t.Fatalf("Begin cycle %d: %v", cycle, r.err)
					}
					stream = r.stream
				case <-ctx.Done():
					t.Fatal("Begin did not return after ready:", ctx.Err())
				}
				assertResidentLog(t, log, readyEvent)
				if cycle == 1 && first == stt.CommandCancel {
					if err := stream.Cancel(ctx); err != nil {
						t.Fatalf("Cancel dictation: %v", err)
					}
				} else if text, err := stream.Stop(ctx); err != nil || text != fmt.Sprintf("dictation-%d", cycle) {
					t.Fatalf("Stop cycle %d = %q, %v", cycle, text, err)
				}
				select {
				case _, ok := <-stream.Results():
					if ok {
						// A final result may be buffered; drain with the same deadline.
						for ok {
							select {
							case _, ok = <-stream.Results():
							case <-ctx.Done():
								t.Fatal("dictation Results never closed")
							}
						}
					}
				case <-ctx.Done():
					t.Fatal("dictation Results never closed")
				}
			}
			if err := standby.Cancel(ctx); err != nil {
				t.Fatal("Cancel standby:", err)
			}
			data, err := os.ReadFile(log)
			want := "launch\nwaiting-loaded-1\nloaded-1\nstart\nwaiting-ready-1\nready-1\n" + first +
				"\nwaiting-loaded-2\nloaded-2\nstart\nwaiting-ready-2\nready-2\nstop\nwaiting-loaded-3\nloaded-3\ncancel\n"
			if err != nil || strings.TrimSpace(string(data)) != strings.TrimSpace(want) {
				t.Fatalf("process commands = %q, %v; want %q", data, err, want)
			}
		})
	}
}

func waitResidentLog(t *testing.T, ctx context.Context, path, event string) {
	t.Helper()
	for {
		data, err := os.ReadFile(path)
		if err == nil && slices.Contains(strings.Split(string(data), "\n"), event) {
			return
		}
		select {
		case <-ctx.Done():
			t.Fatalf("missing process log %q: %q, %v", event, data, err)
		case <-time.After(time.Millisecond):
		}
	}
}
func assertResidentLog(t *testing.T, path, event string) {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil || !slices.Contains(strings.Split(string(data), "\n"), event) {
		t.Fatalf("returned before process logged %q: %q, %v", event, data, err)
	}
}
func releaseResidentGate(t *testing.T, log, event string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(filepath.Dir(log), event), nil, 0600); err != nil {
		t.Fatal(err)
	}
}

// Run the actual Python entry point with model stubs; opening audio would fail.
func TestAC8F002ResidentProcessIdleShutdown(t *testing.T) {
	const harness = `import runpy, sys, types
class Recognizer:
    def create_stream(self): return object()
sys.modules["numpy"] = types.SimpleNamespace()
sys.modules["sherpa_onnx"] = types.SimpleNamespace(OnlineRecognizer=types.SimpleNamespace(from_transducer=lambda **kw: Recognizer()))
sys.argv = [sys.argv[1], "--model-dir", "/model", "--manifest", '{"Encoder":"e","Decoder":"d","Joiner":"j","Tokens":"t"}', "--provider", "cpu", "--standby"]
runpy.run_path(sys.argv[0], run_name="__main__")
`
	for _, command := range []string{stt.CommandStop, "eof"} {
		t.Run(command, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			path, err := writeScript(t.TempDir())
			if err != nil {
				t.Fatal(err)
			}
			p, err := prepareProcess(ctx, exec.Command("python3", "-u", "-c", harness, path))
			if err != nil {
				t.Fatal(err)
			}
			defer func() {
				cancel()
				select {
				case <-p.done:
				case <-time.After(time.Second):
					t.Error("idle process was not reaped")
				}
			}()
			select {
			case <-p.Loaded():
			case <-ctx.Done():
				t.Fatal("initial loaded missing")
			}
			if err := p.Err(); err != nil {
				t.Fatal(err)
			}
			if command == "eof" {
				if err := p.stdin.Close(); err != nil {
					t.Fatal(err)
				}
			} else if _, err := p.Stop(ctx); err != nil {
				t.Errorf("idle Stop: %v", err)
			}
			select {
			case <-p.done:
			case <-ctx.Done():
				t.Fatal("idle process did not exit")
			}
			if err := p.Err(); err != nil {
				t.Errorf("idle shutdown: %v", err)
			}
			if !p.cmd.ProcessState.Success() {
				t.Errorf("exit status: %v", p.cmd.ProcessState)
			}
		})
	}
}
