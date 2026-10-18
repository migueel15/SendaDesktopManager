// Package googlecalendar connects Senda to Google Calendar. It owns the OAuth
// flow and the token file; callers receive only short-lived access tokens.
package googlecalendar

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

// ErrNotConnected means no refresh token is stored yet.
var ErrNotConnected = errors.New("google calendar is not connected; run `senda calendar login`")

// storedToken is what Senda keeps on disk between runs. Access tokens are
// short-lived and stay in memory, so only the refresh token is written.
type storedToken struct {
	RefreshToken string `json:"refresh_token"`
}

// TokenStore keeps the refresh token in one file that only the owner can read.
type TokenStore struct {
	Path string
}

// Save writes the refresh token atomically, so an interrupted write never
// leaves a truncated file behind.
func (s TokenStore) Save(refreshToken string) error {
	dir := filepath.Dir(s.Path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}

	data, err := json.Marshal(storedToken{RefreshToken: refreshToken})
	if err != nil {
		return err
	}

	temp, err := os.CreateTemp(dir, ".google-calendar-*.tmp")
	if err != nil {
		return err
	}
	defer os.Remove(temp.Name())

	if err := temp.Chmod(0o600); err != nil {
		temp.Close()
		return err
	}
	if _, err := temp.Write(data); err != nil {
		temp.Close()
		return err
	}
	if err := temp.Close(); err != nil {
		return err
	}
	return os.Rename(temp.Name(), s.Path)
}

// Load returns the stored refresh token. It refuses a file readable by other
// users, because that file grants access to the account.
func (s TokenStore) Load() (string, error) {
	info, err := os.Stat(s.Path)
	if errors.Is(err, fs.ErrNotExist) {
		return "", ErrNotConnected
	}
	if err != nil {
		return "", err
	}
	if info.Mode().Perm()&0o077 != 0 {
		return "", fmt.Errorf("%s has permissions %04o; expected 0600", s.Path, info.Mode().Perm())
	}

	data, err := os.ReadFile(s.Path)
	if err != nil {
		return "", err
	}
	var stored storedToken
	if err := json.Unmarshal(data, &stored); err != nil {
		return "", fmt.Errorf("%s is not valid: %w", s.Path, err)
	}
	if stored.RefreshToken == "" {
		return "", ErrNotConnected
	}
	return stored.RefreshToken, nil
}

// Delete removes the token file. A missing file is not an error.
func (s TokenStore) Delete() error {
	err := os.Remove(s.Path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	return err
}
