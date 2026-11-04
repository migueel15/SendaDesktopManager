package integration

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestMigrateSendaFolder(t *testing.T) {
	hypr := t.TempDir()
	dir := filepath.Join(hypr, "senda")
	os.MkdirAll(dir, 0o755)
	os.WriteFile(filepath.Join(dir, "init.lua"), []byte("-- Generado por Senda. No modificar manualmente.\n"), 0o644)
	os.WriteFile(filepath.Join(hypr, "hyprland.lua"), []byte("a\nrequire(\"senda.init\") -- Senda: referencia gestionada\nb\n"), 0o644)

	if _, err := migrateSendaFolder(hypr); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatal("old folder should be gone")
	}
	data, _ := os.ReadFile(filepath.Join(hypr, "hyprland.lua"))
	if !strings.Contains(string(data), managedReference) || strings.Contains(string(data), "senda") {
		t.Fatalf("reference not replaced: %q", data)
	}
}
