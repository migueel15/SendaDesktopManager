package googlecalendar

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestTokenStoreRoundTripWritesOwnerOnlyFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", "google-calendar.json")
	store := TokenStore{Path: path}

	if err := store.Save("refresh-1"); err != nil {
		t.Fatalf("Save() error = %v", err)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if mode := info.Mode().Perm(); mode != 0o600 {
		t.Fatalf("token mode = %04o, want 0600", mode)
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
	store := TokenStore{Path: filepath.Join(t.TempDir(), "missing.json")}

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

	_, err := TokenStore{Path: path}.Load()
	if err == nil {
		t.Fatal("Load() succeeded for a 0644 token file")
	}
}

func TestTokenStoreDeleteIsIdempotent(t *testing.T) {
	store := TokenStore{Path: filepath.Join(t.TempDir(), "google-calendar.json")}

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
