package integration

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNewerGenerator(t *testing.T) {
	dir := t.TempDir()
	if newerGenerator(dir, 100) {
		t.Fatal("a module without a stamp must stay writable")
	}
	if err := os.WriteFile(filepath.Join(dir, generatorFile), []byte("100"), 0o644); err != nil {
		t.Fatal(err)
	}
	for built, want := range map[int64]bool{99: true, 100: false, 101: false} {
		if got := newerGenerator(dir, built); got != want {
			t.Errorf("built %d: got %v, want %v", built, got, want)
		}
	}
}
