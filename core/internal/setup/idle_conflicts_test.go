package setup

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/migueel15/Zenda/core/internal/hyprland/integration"
)

func resolve(answers string, accepted, session bool) (string, []string) {
	out := &strings.Builder{}
	w := resolveIdleConflicts(bufio.NewReader(strings.NewReader(answers)), out, accepted, session)
	return out.String(), w
}

func TestResolveIdleUnit(t *testing.T) {
	for _, tc := range []struct {
		answer   string
		disabled bool
	}{{"s\n", true}, {"\n", false}} {
		isolate(t, 0)
		var calls []string
		systemctlUser = func(args ...string) (string, error) {
			calls = append(calls, strings.Join(args, " "))
			if args[0] == "is-enabled" {
				return "enabled", nil
			}
			return "active", nil
		}
		out, warnings := resolve(tc.answer, false, false)
		if !strings.Contains(out, "systemd gestiona hypridle") {
			t.Fatalf("no question: %s", out)
		}
		got := strings.Contains(strings.Join(calls, ";"), "disable --now "+idleUnit)
		if got != tc.disabled || (len(warnings) == 0) == !tc.disabled {
			t.Fatalf("answer %q: disabled %t, warnings %v", tc.answer, got, warnings)
		}
	}
}

func TestResolveIdleAutostart(t *testing.T) {
	home := isolate(t, 0)
	lua := filepath.Join(home, "hypr", "hyprland.lua")
	conf := filepath.Join(home, "hypr", "extra.conf")
	writeFile(t, lua, "hl.exec_once(\"hypridle\")\n-- hl.exec_once(\"hypridle\")\nother()\n")
	writeFile(t, conf, "  exec-once = hypridle\nexec-once = hypridle -c "+integration.IdlePath()+"\n")
	if _, w := resolve("\n", false, false); len(w) != 1 {
		t.Fatalf("declined: warnings %v", w)
	}
	if b, _ := os.ReadFile(lua); !strings.HasPrefix(string(b), "hl.exec") {
		t.Fatalf("changed without consent: %q", b)
	}
	if _, w := resolve("s\n", false, false); len(w) != 0 {
		t.Fatal(w)
	}
	if b, _ := os.ReadFile(lua); string(b) != "-- hl.exec_once(\"hypridle\")\n-- hl.exec_once(\"hypridle\")\nother()\n" {
		t.Fatalf("lua: %q", b)
	}
	if b, _ := os.ReadFile(conf); !strings.HasPrefix(string(b), "  # exec-once = hypridle\nexec-once = hypridle -c ") {
		t.Fatalf("conf: %q", b)
	}
	if found := findIdleAutostart(); len(found) != 0 {
		t.Fatalf("still found: %v", found)
	}
}

func TestResolveIdleProcesses(t *testing.T) {
	isolate(t, 0)
	idleProcesses = func(string, int, string) (integration.Processes, error) {
		return integration.Processes{External: 1, Own: 1}, nil
	}
	var stoppedExt, stoppedOwn bool
	stopExternalIdle = func() string { stoppedExt = true; return "" }
	stopUnmanagedIdle = func() string { stoppedOwn = true; return "" }
	out, _ := resolve("\n\n", false, true)
	if stoppedExt || stoppedOwn || !strings.Contains(out, "¿Cerrarlo") || !strings.Contains(out, "¿Reiniciarlo") {
		t.Fatalf("declined: ext %t own %t\n%s", stoppedExt, stoppedOwn, out)
	}
	resolve("s\ns\n", false, true)
	if !stoppedExt || !stoppedOwn {
		t.Fatalf("accepted: ext %t own %t", stoppedExt, stoppedOwn)
	}
	stoppedExt = false
	idleManaged = func() bool { return true }
	out, _ = resolve("", true, true)
	if !stoppedExt || strings.Contains(out, "¿") {
		t.Fatalf("accepted earlier or managed: ext %t\n%s", stoppedExt, out)
	}
}
