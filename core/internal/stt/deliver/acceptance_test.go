package deliver

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type call struct {
	name  string
	args  []string
	stdin string
}

type recorder struct {
	calls []call
	class string
}

func (r *recorder) run(_ context.Context, stdin io.Reader, name string, args ...string) ([]byte, error) {
	c := call{name: name, args: args}
	if stdin != nil {
		data, _ := io.ReadAll(stdin)
		c.stdin = string(data)
	}
	r.calls = append(r.calls, c)
	if name == "hyprctl" && len(args) > 0 && args[0] == "dispatch" {
		return []byte("ok\n"), nil
	}
	if name == "hyprctl" {
		return []byte(`{"class":"` + r.class + `"}`), nil
	}
	return nil, nil
}

// pasteCall reports whether c is the Hyprland paste dispatch.
func pasteCall(c call) bool {
	return c.name == "hyprctl" && len(c.args) > 0 && c.args[0] == "dispatch"
}

func (r *recorder) find(name string) []call {
	var found []call
	for _, c := range r.calls {
		if c.name == name {
			found = append(found, c)
		}
	}
	return found
}

func settings(mode stt.PasteMode) stt.Settings {
	s := stt.LoadSettings(nil)
	s.PasteMode = mode
	return s
}

func TestAC5ClipboardModeOnlyCopies(t *testing.T) {
	r := &recorder{class: "firefox"}
	if err := New(r.run).Deliver(context.Background(), "hola mundo", settings(stt.PasteClipboard)); err != nil {
		t.Fatalf("Deliver = %v", err)
	}
	copies := r.find("wl-copy")
	if len(copies) != 1 || copies[0].stdin != "hola mundo" {
		t.Fatalf("wl-copy calls = %+v", copies)
	}
	for _, c := range r.calls {
		if pasteCall(c) {
			t.Fatalf("paste ran: %+v", r.calls)
		}
	}
}

func TestAC5PasteModeUsesCtrlV(t *testing.T) {
	r := &recorder{class: "firefox"}
	if err := New(r.run).Deliver(context.Background(), "hola", settings(stt.PasteDirect)); err != nil {
		t.Fatalf("Deliver = %v", err)
	}
	assertPaste(t, r, "hl.dsp.send_shortcut({mods = \"CTRL\", key = \"V\"})")
}

func TestAC5PasteModeInTerminalUsesCtrlShiftV(t *testing.T) {
	r := &recorder{class: "kitty"}
	if err := New(r.run).Deliver(context.Background(), "hola", settings(stt.PasteDirect)); err != nil {
		t.Fatalf("Deliver = %v", err)
	}
	assertPaste(t, r, "hl.dsp.send_shortcut({mods = \"CTRL SHIFT\", key = \"V\"})")
}

func assertPaste(t *testing.T, r *recorder, wantDispatch string) {
	t.Helper()
	copyAt, typeAt := -1, -1
	for i, c := range r.calls {
		switch c.name {
		case "wl-copy":
			copyAt = i
			if c.stdin != "hola" {
				t.Errorf("wl-copy stdin = %q", c.stdin)
			}
		case "hyprctl":
			if !pasteCall(c) {
				continue
			}
			typeAt = i
			if want := []string{"dispatch", wantDispatch}; !slices.Equal(c.args, want) {
				t.Errorf("paste args = %v, want %v", c.args, want)
			}
		}
	}
	if copyAt < 0 || typeAt < 0 || copyAt > typeAt {
		t.Fatalf("expected wl-copy before the paste dispatch: %+v", r.calls)
	}
}

func TestAC5EmptyTextDoesNothing(t *testing.T) {
	for _, text := range []string{"", "   "} {
		r := &recorder{class: "kitty"}
		if err := New(r.run).Deliver(context.Background(), text, settings(stt.PasteDirect)); err != nil {
			t.Fatalf("Deliver(%q) = %v", text, err)
		}
		if len(r.calls) != 0 {
			t.Fatalf("Deliver(%q) ran %+v", text, r.calls)
		}
	}
}

// The fake wl-copy exits while its child keeps the inherited stdout open.
func TestAC1F002ClipboardChildDoesNotBlock(t *testing.T) {
	for _, deliver := range []bool{false, true} {
		t.Run(fmt.Sprintf("deliver=%t", deliver), func(t *testing.T) {
			dir := t.TempDir()
			pid, copied := filepath.Join(dir, "child.pid"), filepath.Join(dir, "copied.txt")
			script := "#!/bin/sh\ncat > '" + copied + "'\nsleep 10 &\necho $! > '" + pid + "'\n"
			if err := os.WriteFile(filepath.Join(dir, "wl-copy"), []byte(script), 0700); err != nil {
				t.Fatal(err)
			}
			t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
			t.Cleanup(func() {
				data, _ := os.ReadFile(pid)
				n, _ := strconv.Atoi(strings.TrimSpace(string(data)))
				if n > 0 {
					_ = syscall.Kill(n, syscall.SIGKILL)
				}
			})
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			done := make(chan error, 1)
			go func() {
				if deliver {
					done <- New(stt.ExecRunner).Deliver(ctx, "hola", settings(stt.PasteClipboard))
					return
				}
				_, err := stt.DetachedRunner(ctx, strings.NewReader("hola"), "wl-copy")
				done <- err
			}()
			select {
			case err := <-done:
				if err != nil {
					t.Fatal(err)
				}
			case <-time.After(time.Second):
				t.Fatal("clipboard command did not return in less than 1 s")
			}
			data, err := os.ReadFile(copied)
			if err != nil || string(data) != "hola" {
				t.Fatalf("copied = %q, %v", data, err)
			}
			data, err = os.ReadFile(pid)
			n, parseErr := strconv.Atoi(strings.TrimSpace(string(data)))
			if err != nil || parseErr != nil || n <= 0 {
				t.Fatalf("child pid = %q, %v, %v", data, err, parseErr)
			}
			if err := syscall.Kill(n, 0); err != nil {
				t.Fatalf("child should still be alive: %v", err)
			}
		})
	}
}
