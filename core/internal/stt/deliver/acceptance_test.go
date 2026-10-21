package deliver

import (
	"context"
	"io"
	"slices"
	"testing"

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
	if name == "hyprctl" {
		return []byte(`{"class":"` + r.class + `"}`), nil
	}
	return nil, nil
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
	if len(r.find("wtype")) != 0 {
		t.Fatalf("wtype ran: %+v", r.calls)
	}
}

func TestAC5PasteModeUsesCtrlV(t *testing.T) {
	r := &recorder{class: "firefox"}
	if err := New(r.run).Deliver(context.Background(), "hola", settings(stt.PasteDirect)); err != nil {
		t.Fatalf("Deliver = %v", err)
	}
	assertPaste(t, r, []string{"-M", "ctrl", "v", "-m", "ctrl"})
}

func TestAC5PasteModeInTerminalUsesCtrlShiftV(t *testing.T) {
	r := &recorder{class: "kitty"}
	if err := New(r.run).Deliver(context.Background(), "hola", settings(stt.PasteDirect)); err != nil {
		t.Fatalf("Deliver = %v", err)
	}
	assertPaste(t, r, []string{"-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"})
}

func assertPaste(t *testing.T, r *recorder, wantArgs []string) {
	t.Helper()
	copyAt, typeAt := -1, -1
	for i, c := range r.calls {
		switch c.name {
		case "wl-copy":
			copyAt = i
			if c.stdin != "hola" {
				t.Errorf("wl-copy stdin = %q", c.stdin)
			}
		case "wtype":
			typeAt = i
			if !slices.Equal(c.args, wantArgs) {
				t.Errorf("wtype args = %v, want %v", c.args, wantArgs)
			}
		}
	}
	if copyAt < 0 || typeAt < 0 || copyAt > typeAt {
		t.Fatalf("expected wl-copy before wtype: %+v", r.calls)
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
