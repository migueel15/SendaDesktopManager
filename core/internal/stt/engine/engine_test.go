package engine

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestEngineUsesManifestAndEmbeddedScript(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "bin")
	if err := os.Mkdir(bin, 0700); err != nil {
		t.Fatal(err)
	}
	python := filepath.Join(bin, "python")
	// This fake interpreter verifies the invocation without sherpa-onnx installed.
	body := "#!/bin/sh\n" + `test "$1" = -u || exit 2
test -f "$2" || exit 3
test "$5" = --manifest || exit 4
case "$6" in *custom-encoder*) ;; *) exit 5;; esac
printf '%s\n' '{"event":"ready"}'
read cmd
printf '%s\n' '{"event":"final","text":"texto"}'
`
	if err := os.WriteFile(python, []byte(body), 0700); err != nil {
		t.Fatal(err)
	}
	m := stt.Manifest{Kind: "transducer", Encoder: "custom-encoder", Decoder: "d", Joiner: "j", Tokens: "t"}
	if err := stt.WriteManifest(dir, m); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	s, err := (&engine{python: python}).Start(ctx, stt.EngineOptions{ModelDir: dir, Provider: "cpu"})
	if err != nil {
		t.Fatal(err)
	}
	if text, err := s.Stop(ctx); text != "texto" || err != nil {
		t.Fatalf("%q, %v", text, err)
	}
	path := filepath.Join(dir, "stt-engine.py")
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := writeScript(dir); err != nil {
		t.Fatal(err)
	}
	info2, _ := os.Stat(path)
	if !os.SameFile(info, info2) {
		t.Fatal("unchanged script was rewritten")
	}
	if err := os.WriteFile(path, []byte("stale"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := writeScript(dir); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if string(data) != string(script) {
		t.Fatal("script was not refreshed")
	}
	if _, err := (&engine{python: python}).Start(ctx, stt.EngineOptions{ModelDir: dir, Provider: "bad"}); err == nil {
		t.Fatal("invalid provider accepted")
	}
}

func TestPythonProtocolWithoutSherpa(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Fatal(err)
	}
	for _, mode := range []string{"normal", "decode-error", "microphone-error", "cancel"} {
		t.Run(mode, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			cmd := exec.CommandContext(ctx, python, "testdata/exercise.py", mode)
			cmd.Env = append(os.Environ(), "PYTHONDONTWRITEBYTECODE=1")
			out, err := cmd.CombinedOutput()
			if err != nil {
				t.Fatalf("%v\n%s", err, out)
			}
			if !strings.Contains(string(out), "PASS") {
				t.Fatal(string(out))
			}
		})
	}
}

func TestEnginePrepareUsesStandby(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "bin")
	if err := os.Mkdir(bin, 0700); err != nil {
		t.Fatal(err)
	}
	python := filepath.Join(bin, "python")
	body := "#!/bin/sh\n" + `test "$1" = -u && test -f "$2" || exit 2
 test "$5" = --manifest || exit 3
 case "$6" in *custom-encoder*) ;; *) exit 4;; esac
 test "${11}" = --standby || exit 5
 printf '%s\n' '{"event":"loaded"}'
 read cmd
 test "$cmd" = start || exit 6
 printf '%s\n' '{"event":"ready"}'
 read cmd
 test "$cmd" = cancel
 `
	if err := os.WriteFile(python, []byte(body), 0700); err != nil {
		t.Fatal(err)
	}
	m := stt.Manifest{Kind: "transducer", Encoder: "custom-encoder", Decoder: "d", Joiner: "j", Tokens: "t"}
	if err := stt.WriteManifest(dir, m); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	e := &engine{python: python}
	standby, err := e.Prepare(ctx, stt.EngineOptions{ModelDir: dir, Provider: "cpu"})
	if err != nil {
		t.Fatal(err)
	}
	select {
	case <-standby.Loaded():
	case <-ctx.Done():
		t.Fatal(ctx.Err())
	}
	if standby.Err() != nil {
		t.Fatal(standby.Err())
	}
	stream, err := standby.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if err := stream.Cancel(ctx); err != nil {
		t.Fatal(err)
	}
}

func TestPythonStandbyDoesNotRecordBeforeBegin(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Fatal(err)
	}
	// Load the real embedded script with minimal model dependencies. The recorder
	// remains a real child process so microphone startup and cleanup are observable.
	harness := `import runpy, sys, types
 class Stream:
     pass
 class Recognizer:
     def create_stream(self): return Stream()
 sys.modules["numpy"] = types.SimpleNamespace()
 sys.modules["sherpa_onnx"] = types.SimpleNamespace(OnlineRecognizer=types.SimpleNamespace(from_transducer=lambda **kw: Recognizer()))
 sys.argv = [sys.argv[1], "--model-dir", "/model", "--manifest", '{"Encoder":"e","Decoder":"d","Joiner":"j","Tokens":"t"}', "--provider", "cpu", "--standby"]
 runpy.run_path(sys.argv[0], run_name="__main__")
 `
	// Remove the Go literal's indentation before passing this Python harness.
	harness = strings.ReplaceAll(harness, "\n ", "\n")
	for _, begin := range []bool{false, true} {
		t.Run(map[bool]string{false: "cancel", true: "begin"}[begin], func(t *testing.T) {
			dir := t.TempDir()
			log := filepath.Join(dir, "record.log")
			body := "#!/bin/sh\necho record > '" + log + "'\nexec sleep 60\n"
			if err := os.WriteFile(filepath.Join(dir, "pw-record"), []byte(body), 0700); err != nil {
				t.Fatal(err)
			}
			path, err := writeScript(dir)
			if err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			cmd := exec.Command(python, "-u", "-c", harness, path)
			cmd.Env = append(os.Environ(), "PATH="+dir+string(os.PathListSeparator)+os.Getenv("PATH"), "PYTHONDONTWRITEBYTECODE=1")
			p, err := prepareProcess(ctx, cmd)
			if err != nil {
				t.Fatal(err)
			}
			select {
			case <-p.Loaded():
			case <-ctx.Done():
				t.Fatal(ctx.Err())
			}
			if p.Err() != nil {
				t.Fatal(p.Err())
			}
			time.Sleep(80 * time.Millisecond)
			if _, err := os.Stat(log); !os.IsNotExist(err) {
				t.Fatalf("recorder started before Begin: %v", err)
			}
			if begin {
				if _, err := p.Begin(ctx); err != nil {
					t.Fatal(err)
				}
				deadline := time.Now().Add(time.Second)
				for {
					if data, err := os.ReadFile(log); err == nil && string(data) == "record\n" {
						break
					}
					if time.Now().After(deadline) {
						t.Fatal("recorder did not start")
					}
					time.Sleep(time.Millisecond)
				}
			}
			if err := p.Cancel(ctx); err != nil {
				t.Fatal(err)
			}
		})
	}
}
