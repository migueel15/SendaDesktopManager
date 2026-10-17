package config

import (
	"os"
	"path/filepath"
	"testing"
)

func writeConfig(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "config")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestLoadMissingFileIsEmpty(t *testing.T) {
	values, err := Load(filepath.Join(t.TempDir(), "missing"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if len(values) != 0 {
		t.Fatalf("Load() = %v, want empty", values)
	}
}

func TestLoadParsesKeyValues(t *testing.T) {
	path := writeConfig(t, `# comentario
SENDA_HOME=/opt/senda
export DORLAB_API_KEY='secret value'
SENDA_DISCORD_BRIDGE="/tmp/bridge.py" # nota
`)

	values, err := Load(path)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	want := map[string]string{
		"SENDA_HOME":           "/opt/senda",
		"DORLAB_API_KEY":       "secret value",
		"SENDA_DISCORD_BRIDGE": "/tmp/bridge.py",
	}
	for key, value := range want {
		if values[key] != value {
			t.Fatalf("values[%q] = %q, want %q", key, values[key], value)
		}
	}
}

func TestLoadRejectsLineWithoutEquals(t *testing.T) {
	path := writeConfig(t, "SENDA_HOME /opt/senda\n")

	if _, err := Load(path); err == nil {
		t.Fatal("Load() error = nil, want error for a line without '='")
	}
}
