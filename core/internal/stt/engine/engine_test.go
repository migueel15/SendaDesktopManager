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
