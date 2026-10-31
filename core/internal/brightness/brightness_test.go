package brightness

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParsePercent(t *testing.T) {
	got, err := parsePercent("intel_backlight,backlight,4800,50%,9600\n")
	if err != nil || got != 50 {
		t.Fatalf("parsePercent() = %d, %v", got, err)
	}
	for _, bad := range []string{"", "a,b,c", "a,b,c,x%,e"} {
		if _, err := parsePercent(bad); err == nil {
			t.Errorf("parsePercent(%q) expected error", bad)
		}
	}
}

func TestHasBacklight(t *testing.T) {
	dir := t.TempDir()
	if hasBacklight(filepath.Join(dir, "missing")) || hasBacklight(dir) {
		t.Fatal("expected no backlight")
	}
	if err := os.Mkdir(filepath.Join(dir, "intel_backlight"), 0o755); err != nil {
		t.Fatal(err)
	}
	if !hasBacklight(dir) {
		t.Fatal("expected a backlight")
	}
}
