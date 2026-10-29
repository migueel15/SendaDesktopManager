package hyprctl

import (
	"context"
	"errors"
	"io"
	"slices"
	"strings"
	"testing"
)

func fake(reply string, err error, got *[]string) Runner {
	return func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		*got = append([]string{name}, args...)
		return []byte(reply), err
	}
}

func TestSendShortcutDispatchesAndChecksReply(t *testing.T) {
	var got []string
	if err := New(fake("ok\n", nil, &got)).SendShortcut(context.Background(), "CTRL SHIFT", "V"); err != nil {
		t.Fatal(err)
	}
	want := []string{"hyprctl", "dispatch", `hl.dsp.send_shortcut({mods = "CTRL SHIFT", key = "V"})`}
	if !slices.Equal(got, want) {
		t.Fatalf("args = %q", got)
	}
	if err := New(fake("error: nope", nil, &got)).Exit(context.Background()); err == nil || !strings.Contains(err.Error(), "nope") {
		t.Fatalf("unexpected reply accepted: %v", err)
	}
	if err := New(fake("", errors.New("boom"), &got)).Exit(context.Background()); err == nil {
		t.Fatal("command failure accepted")
	}
}

func TestQueriesUseJSON(t *testing.T) {
	var got []string
	w, err := New(fake(`{"address":"0x1","class":"kitty"}`, nil, &got)).ActiveWindow(context.Background())
	if err != nil || w.Class != "kitty" || !slices.Equal(got, []string{"hyprctl", "-j", "activewindow"}) {
		t.Fatalf("window = %+v, %v, args %q", w, err, got)
	}
	names, err := New(fake(`{"keyboards":[{"name":"a"},{"name":"b"}]}`, nil, &got)).Keyboards(context.Background())
	if err != nil || !slices.Equal(names, []string{"a", "b"}) {
		t.Fatalf("keyboards = %v, %v", names, err)
	}
}

func TestFocusWindowRejectsInvalidAddress(t *testing.T) {
	var got []string
	if err := New(fake("ok", nil, &got)).FocusWindow(context.Background(), "x; rm"); err == nil || got != nil {
		t.Fatalf("invalid address dispatched: %v %q", err, got)
	}
}

func TestReloadFailsOnConfigErrors(t *testing.T) {
	replies := []string{"ok", "line 3: bad"}
	run := func(context.Context, io.Reader, string, ...string) ([]byte, error) {
		r := replies[0]
		replies = replies[1:]
		return []byte(r), nil
	}
	if err := New(run).Reload(context.Background()); err == nil || !strings.Contains(err.Error(), "bad") {
		t.Fatalf("Reload = %v", err)
	}
}

func TestBindLua(t *testing.T) {
	got := BindLua("ALT + ntilde", DspExec("senda stt toggle"), BindOptions{Description: "d", Universal: true})
	want := `hl.bind("ALT + ntilde", hl.dsp.exec_cmd("senda stt toggle"), { submap_universal = true, description = "d" })`
	if got != want {
		t.Fatalf("got %s", got)
	}
}
