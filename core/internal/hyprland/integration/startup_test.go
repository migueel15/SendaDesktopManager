package integration

import (
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
)

func TestStartupCommands(t *testing.T) {
	cases := []struct {
		entry StartupEntry
		want  string
	}{
		{StartupEntry{Kind: StartupApp, Target: "firefox --new-window"}, "firefox --new-window"},
		{StartupEntry{Kind: StartupScript, Target: "~/it's.sh"}, `"$HOME"/'it'\''s.sh'`},
		{StartupEntry{Kind: StartupFile, Target: "/tmp/a b.pdf"}, "xdg-open '/tmp/a b.pdf'"},
	}
	for _, c := range cases {
		if got := c.entry.command(); got != c.want {
			t.Errorf("got %s, want %s", got, c.want)
		}
	}
}

func TestNewStartupEntryStoresPortablePath(t *testing.T) {
	t.Setenv("HOME", "/home/test")
	got, err := NewStartupEntry(StartupScript, "", "/home/test/bin/run.sh")
	if err != nil {
		t.Fatal(err)
	}
	want := StartupEntry{Kind: StartupScript, Name: "run.sh", Target: "~/bin/run.sh", Enabled: true}
	if got != want {
		t.Fatalf("got %#v", got)
	}
}

func TestStartupValidation(t *testing.T) {
	for _, e := range []StartupEntry{
		{Kind: StartupApp},
		{Kind: "other", Target: "x"},
		{Kind: StartupFile, Target: "relative.txt"},
		{Kind: StartupApp, Target: "a\nb"},
	} {
		if e.Validate() == nil {
			t.Errorf("%#v should be invalid", e)
		}
	}
}

func TestStartupModuleSkipsDisabledEntries(t *testing.T) {
	got, err := renderStartupModule(moduleInput{Command: "senda", Settings: Settings{Startup: []StartupEntry{
		{Kind: StartupApp, Target: "firefox", Enabled: true},
		{Kind: StartupApp, Target: "discord"},
	}}})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, `hl.exec_cmd("firefox")`) || !strings.Contains(got, "input sync") || strings.Contains(got, "discord") {
		t.Fatal(got)
	}
}

func TestStartupRoundTripAndEmptying(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config")
	want := []StartupEntry{{Kind: StartupApp, Name: "A", Target: `sh -c "x y"`, Enabled: true}}
	if err := SaveStartup(path, want); err != nil {
		t.Fatal(err)
	}
	values, err := config.Load(path)
	if err != nil {
		t.Fatal(err)
	}
	got, err := LoadSettings(values)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got.Startup, want) {
		t.Fatalf("got %#v", got.Startup)
	}
	if err := SaveStartup(path, nil); err != nil {
		t.Fatal(err)
	}
	values, _ = config.Load(path)
	if got, _ := ParseStartup(values[KeyStartup]); len(got) != 0 {
		t.Fatalf("got %#v", got)
	}
}
