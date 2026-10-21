package binds

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func fixedRunner(out string, err error) stt.Runner {
	return func(context.Context, io.Reader, string, ...string) ([]byte, error) {
		return []byte(out), err
	}
}

func TestAC7NormalizeShortcut(t *testing.T) {
	got, err := NormalizeShortcut("alt+ñ")
	if err != nil || got != "ALT + ntilde" {
		t.Fatalf("NormalizeShortcut = %q, %v", got, err)
	}
}

func TestAC7NormalizeShortcutRejectsInvalid(t *testing.T) {
	for _, in := range []string{"", "alt+", "+", "alt + ; rm", "alt+b c", `alt+"x"`} {
		if got, err := NormalizeShortcut(in); err == nil {
			t.Errorf("NormalizeShortcut(%q) = %q, want error", in, got)
		}
	}
}

func TestAC7RenderBindsAndSubmap(t *testing.T) {
	out, err := Render("ALT + ntilde", "senda")
	if err != nil {
		t.Fatalf("Render = %v", err)
	}
	text := string(out)
	if !strings.Contains(text, `hl.bind("ALT + ntilde", hl.dsp.exec_cmd("senda stt toggle")`) {
		t.Errorf("missing toggle bind:\n%s", text)
	}
	if !strings.Contains(text, "submap_universal = true") {
		t.Errorf("missing submap_universal:\n%s", text)
	}
	if !strings.Contains(text, SubmapName) || SubmapName != "senda_stt" {
		t.Errorf("missing submap %q:\n%s", SubmapName, text)
	}
	cancel := strings.Index(text, "senda stt cancel")
	if cancel < 0 {
		t.Fatalf("missing cancel command:\n%s", text)
	}
	submapAt := strings.Index(text, SubmapName)
	if submapAt < 0 || submapAt > cancel {
		t.Errorf("cancel is not inside the %s submap:\n%s", SubmapName, text)
	}
	lineStart := strings.LastIndex(text[:cancel], "\n") + 1
	lineEnd := cancel + strings.Index(text[cancel:]+"\n", "\n")
	if line := text[lineStart:lineEnd]; !strings.Contains(line, "escape") {
		t.Errorf("escape is not bound to cancel: %q", line)
	}
}

func TestAC7RenderRejectsInvalidShortcut(t *testing.T) {
	if _, err := Render("alt + ; bad", "senda"); err == nil {
		t.Fatal("Render accepted an invalid shortcut")
	}
}

func TestAC7WriteCreatesDirectory(t *testing.T) {
	path := filepath.Join(t.TempDir(), "hypr", "modules", "senda_binds.lua")
	if err := Write(path, []byte("-- x\n")); err != nil {
		t.Fatalf("Write = %v", err)
	}
	data, err := os.ReadFile(path)
	if err != nil || string(data) != "-- x\n" {
		t.Fatalf("file = %q, %v", data, err)
	}
}

func TestAC7Loaded(t *testing.T) {
	ctx := context.Background()
	if ok, err := Loaded(ctx, fixedRunner("true\n", nil)); err != nil || !ok {
		t.Errorf("Loaded(true) = %v, %v", ok, err)
	}
	if ok, err := Loaded(ctx, fixedRunner("false\n", nil)); err != nil || ok {
		t.Errorf("Loaded(false) = %v, %v", ok, err)
	}
}

const bindsJSON = `[
 {"locked":false,"mouse":false,"release":false,"repeat":false,"non_consuming":false,"modmask":8,"submap":"","key":"ntilde","keycode":0,"catch_all":false,"description":"","dispatcher":"exec","arg":"foreign-tool"},
 {"locked":false,"mouse":false,"release":false,"repeat":false,"non_consuming":false,"modmask":8,"submap":"","key":"ntilde","keycode":0,"catch_all":false,"description":"","dispatcher":"exec","arg":"senda stt toggle"},
 {"locked":false,"mouse":false,"release":false,"repeat":false,"non_consuming":false,"modmask":64,"submap":"","key":"q","keycode":0,"catch_all":false,"description":"","dispatcher":"killactive","arg":""}
]`

func TestAC7ConflictsReturnsForeignBinds(t *testing.T) {
	got, err := Conflicts(context.Background(), fixedRunner(bindsJSON, nil), "ALT + ntilde")
	if err != nil {
		t.Fatalf("Conflicts = %v", err)
	}
	if len(got) != 1 || !strings.Contains(got[0], "foreign-tool") {
		t.Fatalf("Conflicts = %v, want only the foreign bind", got)
	}
}

func TestAC7EnsureDefault(t *testing.T) {
	path := filepath.Join(t.TempDir(), "modules", "senda_binds.lua")
	created, err := EnsureDefault(path, "senda")
	if err != nil || !created {
		t.Fatalf("EnsureDefault = %v, %v", created, err)
	}
	if data, _ := os.ReadFile(path); !strings.Contains(string(data), "hl.bind") {
		t.Fatalf("default module = %q", data)
	}
	if err := os.WriteFile(path, []byte("-- custom\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	created, err = EnsureDefault(path, "senda")
	if err != nil || created {
		t.Fatalf("second EnsureDefault = %v, %v", created, err)
	}
	if data, _ := os.ReadFile(path); string(data) != "-- custom\n" {
		t.Fatalf("existing module overwritten: %q", data)
	}
}

func TestAC7RenderDisabledHasNoBinds(t *testing.T) {
	out := RenderDisabled()
	if len(out) == 0 {
		t.Fatal("RenderDisabled is empty")
	}
	if strings.Contains(string(out), "hl.bind") {
		t.Fatalf("RenderDisabled contains a bind:\n%s", out)
	}
}

func TestAC7SubmapUnavailableWhenModuleNotLoaded(t *testing.T) {
	err := NewSubmap(fixedRunner("false\n", nil)).Enter(context.Background())
	if !errors.Is(err, stt.ErrSubmapUnavailable) {
		t.Fatalf("Enter = %v, want ErrSubmapUnavailable", err)
	}
}
