package release

import (
	"fmt"
	"os"
	"path/filepath"
)

// managedEntries are the entries of the Quickshell tarball that replace the
// matching entries in the data directory during an install or update.
var managedEntries = []string{"quickshell", "scripts", "version"}

// InstallData extracts the Quickshell tarball at tarPath and installs its
// managed entries into dataDir. The archive is unpacked into a hidden staging
// directory next to dataDir, so the renames stay on one filesystem and a
// stale staging directory never appears inside the data directory. A failure
// restores the previous entries.
func InstallData(tarPath string, dataDir string) error {
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return fmt.Errorf("crear %s: %w", dataDir, err)
	}

	stage, err := os.MkdirTemp(filepath.Dir(dataDir), ".senda-install-")
	if err != nil {
		return fmt.Errorf("crear directorio de preparación: %w", err)
	}
	defer os.RemoveAll(stage)

	if err := ExtractDataTarball(tarPath, stage); err != nil {
		return err
	}
	return installManaged(dataDir, stage)
}

// installManaged verifies that stage holds every managed entry, then swaps
// them into dataDir. Each old entry is renamed to "<name>.old" first, and the
// old copies are removed once every entry is in place. A failure restores the
// previous entries.
func installManaged(dataDir string, stage string) error {
	for _, name := range managedEntries {
		if _, err := os.Lstat(filepath.Join(stage, name)); err != nil {
			return fmt.Errorf("el paquete de Quickshell no contiene %s", name)
		}
	}

	var moved, placed []string
	rollback := func() {
		for _, name := range placed {
			os.RemoveAll(filepath.Join(dataDir, name))
		}
		for _, name := range moved {
			dst := filepath.Join(dataDir, name)
			os.Rename(dst+".old", dst)
		}
	}

	for _, name := range managedEntries {
		dst := filepath.Join(dataDir, name)
		old := dst + ".old"

		if err := os.RemoveAll(old); err != nil {
			rollback()
			return fmt.Errorf("limpiar %s: %w", old, err)
		}
		if _, err := os.Lstat(dst); err == nil {
			if err := os.Rename(dst, old); err != nil {
				rollback()
				return fmt.Errorf("mover %s: %w", dst, err)
			}
			moved = append(moved, name)
		}

		if err := os.Rename(filepath.Join(stage, name), dst); err != nil {
			rollback()
			return fmt.Errorf("instalar %s: %w", dst, err)
		}
		placed = append(placed, name)
	}

	// Best effort: any leftover .old copy is removed at the next install.
	for _, name := range moved {
		os.RemoveAll(filepath.Join(dataDir, name) + ".old")
	}
	return nil
}
