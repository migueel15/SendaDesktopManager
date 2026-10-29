package setup

import "testing"

func TestAC9RequirementsIncludeDictationTools(t *testing.T) {
	want := map[string]string{"wl-copy": "wl-clipboard", "pw-record": "pipewire"}
	for _, req := range Requirements {
		if pkg, ok := want[req.Command]; ok {
			if req.Package != pkg {
				t.Errorf("%s package = %q, want %q", req.Command, req.Package, pkg)
			}
			delete(want, req.Command)
		}
	}
	for cmd := range want {
		t.Errorf("Requirements missing %s", cmd)
	}
}

func TestAC9MissingRequirementsListsDictationTools(t *testing.T) {
	lookPath := lookPathFound(commandsExcept("wl-copy", "pw-record")...)
	installed := func(string) bool { return true }
	got := map[string]bool{}
	for _, req := range MissingRequirements(lookPath, installed) {
		got[req.Command] = true
	}
	for _, cmd := range []string{"wl-copy", "pw-record"} {
		if !got[cmd] {
			t.Errorf("MissingRequirements does not list %s: %v", cmd, got)
		}
	}
}
