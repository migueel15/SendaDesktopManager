package legacy

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/migueel15/Zenda/core/internal/config"
)

func TestAliasEnv(t *testing.T) {
	got := map[string]string{}
	AliasEnv([]string{"SENDA_A=1", "SENDA_B=2", "ZENDA_B=3", "OTHER=4"}, func(k, v string) error { got[k] = v; return nil })
	if len(got) != 1 || got["ZENDA_A"] != "1" {
		t.Fatalf("got %v", got)
	}
}

func TestMoveDir(t *testing.T) {
	root := t.TempDir()
	old, neu := filepath.Join(root, "senda"), filepath.Join(root, "zenda")
	os.MkdirAll(old, 0o755)
	os.WriteFile(filepath.Join(old, "config"), []byte("A=1\n"), 0o600)
	if err := MoveDir(old, neu); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(neu, "config")); err != nil {
		t.Fatal(err)
	}
	// Existing destination is never overwritten.
	os.MkdirAll(old, 0o755)
	if err := MoveDir(old, neu); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(old); err != nil {
		t.Fatal("old directory should stay when the new one exists")
	}
}

func TestRenameKeys(t *testing.T) {
	file := filepath.Join(t.TempDir(), "config")
	os.WriteFile(file, []byte("SENDA_THEME=dark\nSENDA_X=old\nZENDA_X=new\nOTHER=1\n"), 0o600)
	if err := RenameKeys(file); err != nil {
		t.Fatal(err)
	}
	values, _ := config.Load(file)
	if values["ZENDA_THEME"] != "dark" || values["ZENDA_X"] != "new" || values["OTHER"] != "1" {
		t.Fatalf("got %v", values)
	}
	if _, ok := values["SENDA_THEME"]; ok {
		t.Fatal("old key kept")
	}
	if err := RenameKeys(filepath.Join(t.TempDir(), "missing")); err != nil {
		t.Fatal(err)
	}
}
