package googlecalendar

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

// Explicit opt-in: create only a synthetic keyring entry isolated by a random path.
func TestSecretServiceIntegration(t *testing.T) {
	if os.Getenv("SENDA_TEST_KEYRING") != "1" {
		t.Skip("set SENDA_TEST_KEYRING=1 to use the desktop keyring")
	}
	path := filepath.Join(t.TempDir(), "google-calendar.json")
	store := TokenStore{Path: path}
	t.Cleanup(func() {
		if err := store.Delete(); err != nil {
			t.Errorf("cleanup: %v", err)
		}
	})
	if _, err := store.Load(); !errors.Is(err, ErrNotConnected) {
		t.Fatalf("missing entry: %v", err)
	}
	if err := store.Save("senda-synthetic-token-1"); err != nil {
		t.Fatal(err)
	}
	got, err := (TokenStore{Path: path}).Load()
	if err != nil || got != "senda-synthetic-token-1" {
		t.Fatalf("persistent round trip failed: %v", err)
	}
	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("plaintext file exists after save")
	}
	if err := store.Save("senda-synthetic-token-2"); err != nil {
		t.Fatal(err)
	}
	got, err = store.Load()
	if err != nil || got != "senda-synthetic-token-2" {
		t.Fatalf("replacement failed: %v", err)
	}
	if err := store.Delete(); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Load(); !errors.Is(err, ErrNotConnected) {
		t.Fatalf("deleted entry: %v", err)
	}
	if err := os.WriteFile(path, []byte(`{"refresh_token":"senda-synthetic-legacy"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	got, err = store.Load()
	if err != nil || got != "senda-synthetic-legacy" {
		t.Fatalf("migration failed: %v", err)
	}
	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("legacy file remains after migration")
	}
	got, err = (TokenStore{Path: path}).Load()
	if err != nil || got != "senda-synthetic-legacy" {
		t.Fatalf("migrated token did not persist: %v", err)
	}
	if err := store.Delete(); err != nil {
		t.Fatal(err)
	}
	if err := store.Delete(); err != nil {
		t.Fatalf("repeated delete: %v", err)
	}
}
