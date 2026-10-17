package paths

import (
	"os"
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
	if got, want := ConfigFile(), "/tmp/xdg-config/senda/config"; got != want {
		t.Fatalf("ConfigFile() = %q, want %q", got, want)
	}
}

func TestRelativeXDGDirsAreIgnored(t *testing.T) {
	t.Setenv("SENDA_HOME", "")
	t.Setenv("XDG_DATA_HOME", "relative/path")

	if want := filepath.Join(".local", "share", "senda"); !strings.HasSuffix(DataDir(), want) {
		t.Fatalf("DataDir() = %q, want the ~/.local/share fallback", DataDir())
	}
}

func TestSendaHomeIgnoresConfigFile(t *testing.T) {
	configHome := t.TempDir()
	dir := filepath.Join(configHome, "senda")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "config"), []byte("SENDA_HOME=/from/config\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("SENDA_HOME", "")
	t.Setenv("XDG_CONFIG_HOME", configHome)
	t.Setenv("XDG_DATA_HOME", "/tmp/xdg-data")

	if got, want := DataDir(), "/tmp/xdg-data/senda"; got != want {
		t.Fatalf("DataDir() = %q, want %q (SENDA_HOME in config must be ignored)", got, want)
	}
}

func TestSettingReadsEnvThenConfig(t *testing.T) {
	configHome := t.TempDir()
	dir := filepath.Join(configHome, "senda")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "config"), []byte("SENDA_DISCORD_BRIDGE=/from/config.py\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CONFIG_HOME", configHome)

	t.Setenv("SENDA_DISCORD_BRIDGE", "")
	if got := Setting("SENDA_DISCORD_BRIDGE"); got != "/from/config.py" {
		t.Fatalf("Setting() = %q, want value from config file", got)
	}

	t.Setenv("SENDA_DISCORD_BRIDGE", "/from/env.py")
	if got := Setting("SENDA_DISCORD_BRIDGE"); got != "/from/env.py" {
		t.Fatalf("Setting() = %q, want environment value", got)
	}

	if got := Setting("SENDA_UNDEFINED_SETTING"); got != "" {
		t.Fatalf("Setting() = %q, want empty for undefined name", got)
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
