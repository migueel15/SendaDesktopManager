package integration

import (
	"context"
	"encoding/hex"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
)

func TestReadUserStartup(t *testing.T) {
	command := `notify-send "¡Hola!"; printf 'a:b'`
	for _, tc := range []struct {
		name, reply string
		available   bool
		count       int
		wantError   bool
	}{
		{"not exposed", "missing", false, 0, false},
		{"empty", "ready", true, 0, false},
		{"quoted command", "ready\n" + hex.EncodeToString([]byte("Aviso")) + ":" + hex.EncodeToString([]byte(command)), true, 1, false},
		{"invalid table", "invalid", false, 0, true},
		{"invalid encoding", "ready\nzz:aa", false, 0, true},
		{"empty command", "ready\n41:", false, 0, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			calls := 0
			runner := func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
				calls++
				if name != "hyprctl" || len(args) != 2 || args[0] != "repl" {
					t.Fatalf("unexpected command: %s %q", name, args)
				}
				return []byte(tc.reply), nil
			}
			got, err := ReadUserStartup(context.Background(), runner)
			if (err != nil) != tc.wantError || got.Available != tc.available || len(got.Entries) != tc.count || calls != 1 {
				t.Fatalf("got %#v, error %v, calls %d", got, err, calls)
			}
			if tc.count == 1 && (got.Entries[0].Name != "Aviso" || got.Entries[0].Target != command) {
				t.Fatalf("command was changed: %#v", got.Entries[0])
			}
		})
	}
}

func TestReadUserStartupUnavailableSession(t *testing.T) {
	want := errors.New("no session")
	_, err := ReadUserStartup(context.Background(), func(context.Context, io.Reader, string, ...string) ([]byte, error) {
		return nil, want
	})
	if !errors.Is(err, want) {
		t.Fatalf("got %v, want %v", err, want)
	}
}

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
	if !strings.Contains(got, "&& /bin/sh -c 'firefox'") || !strings.Contains(got, "input sync") || strings.Contains(got, "discord") {
		t.Fatal(got)
	}
}

func TestStartupWaitsForActiveService(t *testing.T) {
	for _, tc := range []struct {
		name, startExit, activeExit, command, wantOutput, wantCalls string
		wantError                                                   bool
	}{
		{"start fails", "1", "0", "printf first; printf second", "", "--user start senda.service\n", true},
		{"inactive", "0", "3", "false || printf fallback; printf second", "", "--user start senda.service\n--user is-active --quiet senda.service\n", true},
		{"active", "0", "0", "printf first; printf second", "firstsecond", "--user start senda.service\n--user is-active --quiet senda.service\n", false},
		{"quoting", "0", "0", `printf '%s' "it's ready" # trailing comment`, "it's ready", "--user start senda.service\n--user is-active --quiet senda.service\n", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			log := filepath.Join(dir, "calls")
			// PATH contains only the fake, so this cannot reach real systemctl.
			fake := "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$CALL_LOG\"\ncase \"$2\" in start) exit \"$START_EXIT\";; is-active) exit \"$ACTIVE_EXIT\";; *) exit 99;; esac\n"
			if err := os.WriteFile(filepath.Join(dir, "systemctl"), []byte(fake), 0700); err != nil {
				t.Fatal(err)
			}
			entry := StartupEntry{Kind: StartupApp, Target: tc.command, Enabled: true}
			cmd := exec.Command("/bin/sh", "-c", entry.startupCommand())
			cmd.Env = []string{"PATH=" + dir, "CALL_LOG=" + log, "START_EXIT=" + tc.startExit, "ACTIVE_EXIT=" + tc.activeExit}
			out, err := cmd.CombinedOutput()
			if (err != nil) != tc.wantError || string(out) != tc.wantOutput {
				t.Fatalf("output %q, error %v", out, err)
			}
			calls, err := os.ReadFile(log)
			if err != nil || string(calls) != tc.wantCalls {
				t.Fatalf("calls %q, error %v", calls, err)
			}
			if entry.Target != tc.command {
				t.Fatal("stored command changed")
			}
		})
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
