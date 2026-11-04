// Package legacy migrates an installation made under the previous name
// (Senda) to Zenda. It moves the user's directories, renames the SENDA_*
// settings and accepts SENDA_* environment variables as a temporary alias.
// Every step is idempotent and never overwrites something that already exists
// under the new name.
package legacy

import (
	"errors"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/migueel15/Zenda/core/internal/config"
	"github.com/migueel15/Zenda/core/internal/paths"
)

const (
	oldName   = "senda"
	newName   = "zenda"
	oldPrefix = "SENDA_"
	newPrefix = "ZENDA_"
)

// Apply runs the whole migration. Failures are logged, never fatal: a broken
// migration must not stop the command the user asked for.
func Apply() {
	AliasEnv(os.Environ(), os.Setenv)
	for _, dir := range []struct{ env, fallback string }{
		{"XDG_CONFIG_HOME", ".config"},
		{"XDG_DATA_HOME", ".local/share"},
		{"XDG_STATE_HOME", ".local/state"},
		{"XDG_CACHE_HOME", ".cache"},
	} {
		base := xdgBase(dir.env, dir.fallback)
		if base == "" {
			continue
		}
		if dir.env == "XDG_DATA_HOME" && os.Getenv("ZENDA_HOME") != "" {
			continue
		}
		if err := MoveDir(filepath.Join(base, oldName), filepath.Join(base, newName)); err != nil {
			log.Println("error migrating", filepath.Join(base, oldName)+":", err)
		}
	}
	for _, file := range []string{paths.ConfigFile(), paths.SecretsFile()} {
		if err := RenameKeys(file); err != nil {
			log.Println("error migrating settings in", file+":", err)
		}
	}
}

// AliasEnv exports a ZENDA_* variable for every SENDA_* one that has no
// ZENDA_* counterpart, so children and the interface see the new name.
func AliasEnv(environ []string, set func(key, value string) error) {
	present := map[string]bool{}
	for _, kv := range environ {
		if key, _, ok := strings.Cut(kv, "="); ok {
			present[key] = true
		}
	}
	for _, kv := range environ {
		key, value, ok := strings.Cut(kv, "=")
		if !ok || !strings.HasPrefix(key, oldPrefix) {
			continue
		}
		if neu := newPrefix + strings.TrimPrefix(key, oldPrefix); !present[neu] {
			_ = set(neu, value)
		}
	}
}

// MoveDir renames old to new when old exists and new does not.
func MoveDir(old, neu string) error {
	if _, err := os.Lstat(old); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	if _, err := os.Lstat(neu); err == nil {
		return nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return os.Rename(old, neu)
}

// RenameKeys renames SENDA_* keys of a settings file to ZENDA_*. A ZENDA_*
// key already present wins; the old key is removed either way.
func RenameKeys(path string) error {
	if _, err := os.Stat(path); errors.Is(err, os.ErrNotExist) {
		return nil
	}
	values, err := config.Load(path)
	if err != nil {
		return err
	}
	changes := map[string]string{}
	for key, value := range values {
		if !strings.HasPrefix(key, oldPrefix) {
			continue
		}
		changes[key] = ""
		if neu := newPrefix + strings.TrimPrefix(key, oldPrefix); values[neu] == "" {
			changes[neu] = value
		}
	}
	if len(changes) == 0 {
		return nil
	}
	return config.Set(path, changes)
}

func xdgBase(env, fallback string) string {
	if dir := os.Getenv(env); filepath.IsAbs(dir) {
		return dir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, fallback)
}
