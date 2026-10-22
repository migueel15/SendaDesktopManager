package stt

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestLoadSettings(t *testing.T) {
	defaults := Settings{AudioDucking: true, AudioVolume: 10, ModelID: DefaultModelID, Language: DefaultLanguage,
		PasteMode: PasteDirect, Shortcut: DefaultShortcut, Terminals: DefaultTerminals}
	for _, values := range []map[string]string{nil, {}, {
		KeyModel: "../escape", KeyLanguage: "invalid-language!", KeyPasteMode: "other",
		KeyShortcut: "UNKNOWN + n", KeyTerminals: "kitty,invalid class",
	}, {
		KeyModel: " ", KeyLanguage: " ", KeyPasteMode: " ", KeyShortcut: "ALT +", KeyTerminals: " , , ",
	}} {
		if got := LoadSettings(values); !reflect.DeepEqual(got, defaults) {
			t.Errorf("LoadSettings(%v) = %+v, want %+v", values, got, defaults)
		}
	}
	values := map[string]string{KeyModel: "other-model", KeyLanguage: "en-US", KeyPasteMode: "clipboard",
		KeyShortcut: "SUPER + n", KeyTerminals: " kitty, ,org.example.Terminal,foot "}
	want := Settings{AudioDucking: true, AudioVolume: 10, ModelID: "other-model", Language: "en-US", PasteMode: PasteClipboard,
		Shortcut: "SUPER + n", Terminals: []string{"kitty", "org.example.Terminal", "foot"}}
	if got := LoadSettings(values); !reflect.DeepEqual(got, want) {
		t.Errorf("LoadSettings() = %+v, want %+v", got, want)
	}
	if got := LoadSettings(map[string]string{KeyLanguage: "auto"}); got.Language != "auto" {
		t.Fatalf("auto detection = %q", got.Language)
	}
	got := LoadSettings(nil)
	got.Terminals[0] = "changed"
	if LoadSettings(nil).Terminals[0] != "kitty" {
		t.Fatal("settings share mutable terminal defaults")
	}
}

func TestPaths(t *testing.T) {
	root := t.TempDir()
	t.Setenv("HOME", root)
	for _, tc := range []struct{ name, xdg, override, data string }{
		{"fallback", "", "", filepath.Join(root, ".local", "share", "senda")},
		{"relative-xdg", "relative", "", filepath.Join(root, ".local", "share", "senda")},
		{"xdg", filepath.Join(root, "data"), "", filepath.Join(root, "data", "senda")},
		{"override", filepath.Join(root, "data"), filepath.Join(root, "checkout"), filepath.Join(root, "checkout")},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("XDG_DATA_HOME", tc.xdg)
			t.Setenv("SENDA_HOME", tc.override)
			want := filepath.Join(tc.data, "stt")
			if Dir() != want || ModelsDir() != filepath.Join(want, "models") || RuntimeDir() != filepath.Join(want, "venv") {
				t.Fatalf("paths = %q, %q, %q", Dir(), ModelsDir(), RuntimeDir())
			}
		})
	}
}

func TestManifestRoundTripAndErrors(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "model")
	m := Manifest{ID: DefaultModelID, Kind: "transducer", Encoder: "encoder.int8.onnx",
		Decoder: "decoder.int8.onnx", Joiner: "joiner.int8.onnx", Tokens: "tokens.txt", LanguageOption: true}
	if _, err := ReadManifest(dir); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("missing manifest: %v", err)
	}
	for _, languageOption := range []bool{true, false} {
		m.LanguageOption = languageOption
		if err := WriteManifest(dir, m); err != nil {
			t.Fatal(err)
		}
		if got, err := ReadManifest(dir); err != nil || got != m {
			t.Fatalf("round trip = %+v, %v", got, err)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, ManifestFile), []byte(`{"id":`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := ReadManifest(dir); err == nil {
		t.Fatal("accepted invalid JSON")
	}
	file := filepath.Join(t.TempDir(), "file")
	if err := os.WriteFile(file, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := WriteManifest(file, m); err == nil {
		t.Fatal("wrote manifest through a non-directory")
	}
}

func TestEventWireFormat(t *testing.T) {
	for _, tc := range []struct {
		event Event
		want  string
	}{
		{Event{Type: EventReady}, `{"event":"ready"}`},
		{Event{Type: EventPartial, Text: "hola"}, `{"event":"partial","text":"hola"}`},
		{Event{Type: EventError, Message: "fallo"}, `{"event":"error","message":"fallo"}`},
	} {
		data, err := json.Marshal(tc.event)
		if err != nil || string(data) != tc.want {
			t.Fatalf("event = %s, %v", data, err)
		}
	}
}

func TestExecRunner(t *testing.T) {
	t.Setenv("SENDA_STT_RUNNER_HELPER", "1")
	args := []string{"-test.run=^TestRunnerHelper$", "--", "copy"}
	data, err := ExecRunner(context.Background(), strings.NewReader("hola\n"), os.Args[0], args...)
	if err != nil || string(data) != "hola\n" {
		t.Fatalf("stdin/stdout = %q, %v", data, err)
	}
	data, err = ExecRunner(context.Background(), nil, os.Args[0], args...)
	if err != nil || len(data) != 0 {
		t.Fatalf("nil stdin = %q, %v", data, err)
	}
	_, err = ExecRunner(context.Background(), nil, os.Args[0], "-test.run=^TestRunnerHelper$", "--", "fail")
	var exit *exec.ExitError
	if !errors.As(err, &exit) || exit.ExitCode() != 7 || string(exit.Stderr) != "failure" {
		t.Fatalf("process failure = %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := ExecRunner(ctx, nil, os.Args[0], args...); !errors.Is(err, context.Canceled) {
		t.Fatalf("cancelled process = %v", err)
	}
	if _, err := ExecRunner(context.Background(), nil, filepath.Join(t.TempDir(), "missing")); err == nil {
		t.Fatal("missing executable succeeded")
	}
}

func TestRunnerHelper(t *testing.T) {
	if os.Getenv("SENDA_STT_RUNNER_HELPER") != "1" {
		return
	}
	if os.Args[len(os.Args)-1] == "fail" {
		fmt.Fprint(os.Stderr, "failure")
		os.Exit(7)
	}
	if _, err := io.Copy(os.Stdout, os.Stdin); err != nil {
		os.Exit(8)
	}
	os.Exit(0)
}
