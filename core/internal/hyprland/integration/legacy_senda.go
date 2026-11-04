package integration

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
)

// migrateSendaFolder removes the folder generated under the previous name
// (hypr/senda) and replaces its managed require line in hyprland.lua, so
// Hyprland does not keep importing a folder that no longer exists. Only files
// with the old generated headers are removed.
func migrateSendaFolder(hypr string) ([]string, error) {
	var warnings []string
	dir := filepath.Join(hypr, "senda")
	entries, err := os.ReadDir(dir)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	kept := 0
	for _, e := range entries {
		path := filepath.Join(dir, e.Name())
		ok, err := owned(path, "-- Generado por Senda.", "# Generado por Senda.")
		if err != nil {
			warnings = append(warnings, err.Error())
			kept++
			continue
		}
		if !ok {
			kept++
			continue
		}
		if err := os.Remove(path); err != nil {
			return warnings, err
		}
	}
	if kept == 0 {
		_ = os.Remove(dir)
	} else {
		warnings = append(warnings, "Carpeta antigua conservada, revísala: "+dir)
	}

	main := filepath.Join(hypr, "hyprland.lua")
	info, err := os.Lstat(main)
	if err != nil || !info.Mode().IsRegular() {
		return warnings, nil
	}
	data, err := os.ReadFile(main)
	if err != nil {
		return warnings, err
	}
	lines := strings.Split(string(data), "\n")
	changed := false
	for i, line := range lines {
		if strings.TrimSpace(line) == `require("senda.init") -- Senda: referencia gestionada` {
			lines[i] = managedReference
			changed = true
		}
	}
	if changed {
		return warnings, writePreservingMode(main, []byte(strings.Join(lines, "\n")), info.Mode().Perm())
	}
	return warnings, nil
}
