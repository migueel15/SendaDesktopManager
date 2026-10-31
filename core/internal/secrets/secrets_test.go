package secrets

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
)

type fakeEntry struct {
	values map[string]string
	name   string
	broken bool
}

func (f fakeEntry) Save(value string) error {
	if f.broken {
		return ErrUnavailable
	}
	f.values[f.name] = value
	return nil
}

func (f fakeEntry) Load() (string, error) {
	if f.broken {
		return "", ErrUnavailable
	}
	if value, ok := f.values[f.name]; ok {
		return value, nil
	}
	return "", ErrNotFound
}

func (f fakeEntry) Delete() error {
	if f.broken {
		return ErrUnavailable
	}
	delete(f.values, f.name)
	return nil
}

func testStore(t *testing.T, values map[string]string, broken *bool) Store {
	t.Helper()
	return Store{
		FallbackFile: filepath.Join(t.TempDir(), "secrets"),
		keyring: func(name string) entry {
			return fakeEntry{values: values, name: name, broken: *broken}
		},
	}
}

func writeConfig(t *testing.T, text string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "config")
	if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestMigrateMovesSecretsToKeyring(t *testing.T) {
	keyring, broken := map[string]string{}, false
	store := testStore(t, keyring, &broken)
	path := writeConfig(t, "# mío\nDORLAB_API_KEY=abc\nSENDA_THEME=x\nSENDA_GOOGLE_CLIENT_SECRET=\n")
	if err := store.Migrate(path); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(path)
	if string(data) != "# mío\nSENDA_THEME=x\n" {
		t.Fatalf("config = %q", data)
	}
	if keyring[DorlabAPIKey] != "abc" {
		t.Fatalf("keyring = %v", keyring)
	}
}

func TestMigrateWithoutKeyringUsesPrivateFile(t *testing.T) {
	broken := true
	store := testStore(t, map[string]string{}, &broken)
	path := writeConfig(t, "DORLAB_API_KEY=abc\n")
	if err := store.Migrate(path); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(path); strings.Contains(string(data), "abc") {
		t.Fatalf("config kept the secret: %q", data)
	}
	info, err := os.Stat(store.FallbackFile)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("fallback file: %v %v", info, err)
	}
	if value, err := store.Get(DorlabAPIKey); err != nil || value != "abc" {
		t.Fatalf("Get() = %q, %v", value, err)
	}
}

func TestMigrateKeepsConfigWhenNothingCanStore(t *testing.T) {
	broken := true
	store := testStore(t, map[string]string{}, &broken)
	store.FallbackFile = filepath.Join(writeConfig(t, ""), "secrets") // parent is a file
	path := writeConfig(t, "DORLAB_API_KEY=abc\n")
	if err := store.Migrate(path); err == nil {
		t.Fatal("Migrate() succeeded without storage")
	}
	values, _ := config.Load(path)
	if values[DorlabAPIKey] != "abc" {
		t.Fatalf("value lost: %v", values)
	}
}

func TestGetPromotesFallbackWhenKeyringReturns(t *testing.T) {
	keyring, broken := map[string]string{}, true
	store := testStore(t, keyring, &broken)
	if err := store.Set(DorlabAPIKey, "abc"); err != nil {
		t.Fatal(err)
	}
	broken = false
	if value, err := store.Get(DorlabAPIKey); err != nil || value != "abc" {
		t.Fatalf("Get() = %q, %v", value, err)
	}
	if keyring[DorlabAPIKey] != "abc" {
		t.Fatal("value was not promoted")
	}
	if values, _ := config.Load(store.FallbackFile); values[DorlabAPIKey] != "" {
		t.Fatal("fallback kept the value")
	}
}

func TestGetUndefinedAndDelete(t *testing.T) {
	keyring, broken := map[string]string{DorlabAPIKey: "abc"}, false
	store := testStore(t, keyring, &broken)
	if err := store.Set(DorlabAPIKey, ""); err != nil {
		t.Fatal(err)
	}
	if value, err := store.Get(DorlabAPIKey); err != nil || value != "" {
		t.Fatalf("Get() = %q, %v", value, err)
	}
}
