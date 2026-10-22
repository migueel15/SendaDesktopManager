package googlecalendar

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestTokenStoreRoundTripUsesKeyring(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", "google-calendar.json")
	store := testTokenStore(path)

	if err := store.Save("refresh-1"); err != nil {
		t.Fatalf("Save() error = %v", err)
	}

	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Fatal("Save created a plaintext token file")
	}

	got, err := store.Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if got != "refresh-1" {
		t.Fatalf("Load() = %q, want %q", got, "refresh-1")
	}
}

func TestTokenStoreLoadMissingIsNotConnected(t *testing.T) {
	store := testTokenStore(filepath.Join(t.TempDir(), "missing.json"))

	if _, err := store.Load(); !errors.Is(err, ErrNotConnected) {
		t.Fatalf("Load() error = %v, want ErrNotConnected", err)
	}
}

func TestTokenStoreRefusesWorldReadableFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "google-calendar.json")
	if err := os.WriteFile(path, []byte(`{"refresh_token":"refresh-1"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(path, 0o644); err != nil {
		t.Fatal(err)
	}

	_, err := testTokenStore(path).Load()
	if err == nil {
		t.Fatal("Load() succeeded for a 0644 token file")
	}
}

func TestTokenStoreDeleteIsIdempotent(t *testing.T) {
	store := testTokenStore(filepath.Join(t.TempDir(), "google-calendar.json"))

	if err := store.Delete(); err != nil {
		t.Fatalf("Delete() on missing file error = %v", err)
	}
	if err := store.Save("refresh-1"); err != nil {
		t.Fatal(err)
	}
	if err := store.Delete(); err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	if _, err := store.Load(); !errors.Is(err, ErrNotConnected) {
		t.Fatalf("Load() after Delete error = %v, want ErrNotConnected", err)
	}
}

// Keep unit tests isolated from the user's real desktop keyring.
type memorySecrets struct{ token string }

func (s *memorySecrets) Save(token string) error { s.token = token; return nil }
func (s *memorySecrets) Load() (string, error) {
	if s.token == "" {
		return "", ErrNotConnected
	}
	return s.token, nil
}
func (s *memorySecrets) Delete() error { s.token = ""; return nil }
func testTokenStore(path string) TokenStore {
	return TokenStore{Path: path, secrets: &memorySecrets{}}
}
