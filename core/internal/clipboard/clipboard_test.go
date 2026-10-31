package clipboard

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func texts(t *testing.T, store Store) string {
	t.Helper()
	entries, err := store.List()
	if err != nil {
		t.Fatal(err)
	}
	var result []string
	for _, entry := range entries {
		result = append(result, entry.Text)
	}
	return strings.Join(result, ",")
}

func TestAddOrdersDeduplicatesAndDropsOldest(t *testing.T) {
	store := Store{Path: filepath.Join(t.TempDir(), "state", "history.json")}
	for _, text := range []string{"a", "b", "c", "a", "d"} {
		if err := store.Add(text, 3, time.Now()); err != nil {
			t.Fatal(err)
		}
	}
	if got := texts(t, store); got != "d,a,c" {
		t.Fatalf("history = %q", got)
	}
	info, err := os.Stat(store.Path)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %v, %v", info.Mode(), err)
	}
}

func TestAddIgnoresBlankBinaryAndHugeText(t *testing.T) {
	store := Store{Path: filepath.Join(t.TempDir(), "history.json")}
	for _, text := range []string{" \n", "\xff\xfe", strings.Repeat("x", MaxTextBytes+1)} {
		if err := store.Add(text, 3, time.Now()); err != nil {
			t.Fatal(err)
		}
	}
	if got := texts(t, store); got != "" {
		t.Fatalf("history = %q", got)
	}
}

func TestCaptureSkipsSensitiveAndDisabled(t *testing.T) {
	store := Store{Path: filepath.Join(t.TempDir(), "history.json")}
	on := Settings{Enabled: true, Max: 3}
	cases := []struct {
		state    string
		settings Settings
	}{{"sensitive", on}, {"nil", on}, {"", on}, {"data", Settings{Max: 3}}}
	for _, item := range cases {
		if err := Capture(store, item.state, strings.NewReader("secret"), item.settings, time.Now()); err != nil {
			t.Fatal(err)
		}
	}
	if got := texts(t, store); got != "" {
		t.Fatalf("history = %q", got)
	}
	if err := Capture(store, "data", strings.NewReader("hola"), on, time.Now()); err != nil {
		t.Fatal(err)
	}
	if got := texts(t, store); got != "hola" {
		t.Fatalf("history = %q", got)
	}
}

func TestFindAndClear(t *testing.T) {
	store := Store{Path: filepath.Join(t.TempDir(), "history.json")}
	if err := store.Add("a", 3, time.Now()); err != nil {
		t.Fatal(err)
	}
	entries, _ := store.List()
	if entry, err := store.Find(entries[0].ID); err != nil || entry.Text != "a" {
		t.Fatalf("find = %v, %v", entry, err)
	}
	if err := store.Clear(); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Find(entries[0].ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v", err)
	}
}

func TestLoadSettings(t *testing.T) {
	if got := LoadSettings(map[string]string{}); !got.Enabled || got.Max != DefaultMax {
		t.Fatalf("defaults = %+v", got)
	}
	got := LoadSettings(map[string]string{KeyEnabled: "false", KeyMax: "5000"})
	if got.Enabled || got.Max != DefaultMax {
		t.Fatalf("invalid = %+v", got)
	}
}
