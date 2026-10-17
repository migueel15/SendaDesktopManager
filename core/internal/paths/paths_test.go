package paths

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestDefaultLocationsFollowXDG(t *testing.T) {
	t.Setenv("SENDA_HOME", "")
	t.Setenv("XDG_CONFIG_HOME", "/tmp/xdg-config")
	t.Setenv("XDG_DATA_HOME", "/tmp/xdg-data")

	if got, want := ConfigDir(), "/tmp/xdg-config/senda"; got != want {
		t.Fatalf("ConfigDir() = %q, want %q", got, want)
	}
	if got, want := QuickshellDir(), "/tmp/xdg-data/senda/quickshell"; got != want {
		t.Fatalf("QuickshellDir() = %q, want %q", got, want)
	}
	if got, want := EnvFile(), "/tmp/xdg-config/senda/.env"; got != want {
		t.Fatalf("EnvFile() = %q, want %q", got, want)
	}
}

func TestRelativeXDGDirsAreIgnored(t *testing.T) {
	t.Setenv("SENDA_HOME", "")
	t.Setenv("XDG_DATA_HOME", "relative/path")

	if want := filepath.Join(".local", "share", "senda"); !strings.HasSuffix(DataDir(), want) {
		t.Fatalf("DataDir() = %q, want the ~/.local/share fallback", DataDir())
	}
}

func TestSendaHomeOverridesDataDir(t *testing.T) {
	t.Setenv("SENDA_HOME", "/repo/checkout")

	if got, want := QuickshellDir(), "/repo/checkout/quickshell"; got != want {
		t.Fatalf("QuickshellDir() = %q, want %q", got, want)
	}
	if got, want := VersionFile(), "/repo/checkout/version"; got != want {
		t.Fatalf("VersionFile() = %q, want %q", got, want)
	}
}
