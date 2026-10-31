// Package secrets keeps sensitive settings out of the portable config file.
// Values live in Secret Service; without it they go to a private file outside
// the config folder, which is never shared.
package secrets

import (
	"errors"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
)

const (
	DorlabAPIKey       = "DORLAB_API_KEY"
	GoogleClientSecret = "SENDA_GOOGLE_CLIENT_SECRET"
)

// Names lists every setting that must never stay in the config file.
var Names = []string{DorlabAPIKey, GoogleClientSecret}

// IsSecret reports whether name is one of Names.
func IsSecret(name string) bool {
	for _, candidate := range Names {
		if candidate == name {
			return true
		}
	}
	return false
}

type entry interface {
	Save(string) error
	Load() (string, error)
	Delete() error
}

// Store reads and writes secrets. FallbackFile uses the KEY=VALUE format with
// owner-only permissions.
type Store struct {
	FallbackFile string
	keyring      func(name string) entry
}

func (s Store) entry(name string) entry {
	if s.keyring != nil {
		return s.keyring(name)
	}
	return Keyring{
		Label:      "Senda " + name,
		Attributes: []string{"application", "senda", "type", "setting", "name", name},
	}
}

// Get returns "" when the secret is not defined. A value left in the fallback
// file moves to the keyring as soon as the keyring works again.
func (s Store) Get(name string) (string, error) {
	value, err := s.entry(name).Load()
	if err == nil {
		return value, nil
	}
	saved, fileErr := config.Load(s.FallbackFile)
	if fileErr != nil {
		return "", fileErr
	}
	value = saved[name]
	if value != "" && errors.Is(err, ErrNotFound) {
		if err := s.Set(name, value); err != nil {
			return "", err
		}
	}
	return value, nil
}

// Set stores value, and an empty value removes the secret. It fails only when
// neither the keyring nor the fallback file could keep the value.
func (s Store) Set(name, value string) error {
	if value == "" {
		// A keyring error here leaves an entry only reachable by that keyring,
		// and the caller must know that it was not removed.
		err := s.entry(name).Delete()
		return errors.Join(err, s.clearFallback(name))
	}
	if err := s.entry(name).Save(value); err != nil {
		return config.Set(s.FallbackFile, map[string]string{name: value})
	}
	return s.clearFallback(name)
}

func (s Store) clearFallback(name string) error {
	saved, err := config.Load(s.FallbackFile)
	if err != nil {
		return err
	}
	if _, ok := saved[name]; !ok {
		return nil
	}
	return config.Set(s.FallbackFile, map[string]string{name: ""})
}

// Migrate moves the secrets out of configFile. A key leaves the file only
// after its value is confirmed stored, and the file's value wins because it is
// the one the user wrote last. Without a config file there is nothing to do.
func (s Store) Migrate(configFile string) error {
	values, err := config.Load(configFile)
	if err != nil {
		return err
	}
	remove := map[string]string{}
	for _, name := range Names {
		value, ok := values[name]
		if !ok {
			continue
		}
		if value != "" {
			if err := s.Set(name, value); err != nil {
				return err
			}
		}
		remove[name] = ""
	}
	if len(remove) == 0 {
		return nil
	}
	return config.Set(configFile, remove)
}
