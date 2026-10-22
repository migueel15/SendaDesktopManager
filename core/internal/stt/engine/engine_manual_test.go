//go:build manual

package engine

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// Run with SENDA_STT_TEST_MODEL and SENDA_STT_TEST_PYTHON pointing to a model
// with manifest.json and a Python venv with sherpa-onnx. No microphone required.
func TestManualSpanishWAV(t *testing.T) {
	dir, python := os.Getenv("SENDA_STT_TEST_MODEL"), os.Getenv("SENDA_STT_TEST_PYTHON")
	if dir == "" || python == "" {
		t.Skip("set SENDA_STT_TEST_MODEL and SENDA_STT_TEST_PYTHON")
	}
	m, err := stt.ReadManifest(dir)
	if errors.Is(err, os.ErrNotExist) {
		// The downloaded default-model archive does not ship Senda's manifest.
		m = stt.Manifest{Kind: "transducer", Encoder: "encoder.int8.onnx", Decoder: "decoder.int8.onnx", Joiner: "joiner.int8.onnx", Tokens: "tokens.txt", LanguageOption: true}
		if err := stt.WriteManifest(dir, m); err != nil {
			t.Fatal(err)
		}
		m, err = stt.ReadManifest(dir)
	}
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Second)
	defer cancel()
	wav := filepath.Join(t.TempDir(), "es-16k.wav")
	convert := exec.CommandContext(ctx, "ffmpeg", "-v", "error", "-i", filepath.Join(dir, "test_wavs", "es.wav"), "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", wav)
	if out, err := convert.CombinedOutput(); err != nil {
		t.Fatalf("convert WAV: %v %s", err, out)
	}
	path, err := writeScript(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	manifest, _ := json.Marshal(m)
	start := time.Now()
	p, err := startProcess(ctx, exec.Command(python, "-u", path, "--model-dir", dir, "--manifest", string(manifest), "--provider", "cpu", "--language", "es", "--wav", wav))
	if err != nil {
		t.Fatal(err)
	}
	ready := time.Now()
	var first time.Duration
	var last string
	for result := range p.Results() {
		if first == 0 && result.Text != "" {
			first = time.Since(ready)
		}
		last = result.Text
	}
	text, err := p.Stop(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if first == 0 || text == "" || text != last || !strings.Contains(strings.ToLower(text), "país") {
		t.Fatalf("invalid Spanish transcription: %q (%s)", text, first)
	}
	t.Logf("load=%s first_partial_after_ready=%s total=%s text=%q", ready.Sub(start), first, time.Since(start), text)
}

func TestAC7F002ManualStandbyDoesNotRecordBeforeStart(t *testing.T) {
	dir, python := os.Getenv("SENDA_STT_TEST_MODEL"), os.Getenv("SENDA_STT_TEST_PYTHON")
	if dir == "" || python == "" {
		t.Skip("set SENDA_STT_TEST_MODEL and SENDA_STT_TEST_PYTHON")
	}
	m, err := stt.ReadManifest(dir)
	if err != nil {
		t.Fatal(err)
	}
	temp := t.TempDir()
	log := filepath.Join(temp, "record.log")
	// Keep stdout open without producing audio; cancellation must terminate this process.
	fake := "#!/bin/sh\necho record >> '" + log + "'\nexec sleep 60\n"
	if err := os.WriteFile(filepath.Join(temp, "pw-record"), []byte(fake), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", temp+string(os.PathListSeparator)+os.Getenv("PATH"))
	path, err := writeScript(temp)
	if err != nil {
		t.Fatal(err)
	}
	manifest, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, python, "-u", path, "--model-dir", dir, "--manifest", string(manifest), "--provider", "cpu", "--language", "es", "--standby")
	stdin, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { stdin.Close(); cancel(); _ = cmd.Wait() })
	dec := json.NewDecoder(stdout)
	expect := func(want stt.EventType) {
		t.Helper()
		var event stt.Event
		if err := dec.Decode(&event); err != nil {
			t.Fatalf("waiting for %s: %v", want, err)
		}
		if event.Type != want {
			t.Fatalf("event = %+v, want %s", event, want)
		}
	}
	expect(stt.EventLoaded)
	time.Sleep(200 * time.Millisecond)
	if data, err := os.ReadFile(log); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("pw-record ran before start: %q, %v", data, err)
	}
	if _, err := io.WriteString(stdin, "start\n"); err != nil {
		t.Fatal(err)
	}
	expect(stt.EventReady)
	deadline := time.Now().Add(time.Second)
	for {
		data, err := os.ReadFile(log)
		if err == nil && string(data) == "record\n" {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("pw-record did not run after start: %q, %v", data, err)
		}
		time.Sleep(5 * time.Millisecond)
	}
	if _, err := io.WriteString(stdin, "cancel\n"); err != nil {
		t.Fatal(err)
	}
	if err := cmd.Wait(); err != nil {
		t.Fatalf("cancel: %v: %s", err, stderr.String())
	}
}
