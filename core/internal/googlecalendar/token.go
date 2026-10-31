// Package googlecalendar connects Senda to Google Calendar. It owns the OAuth
// flow and secret storage; callers receive only short-lived access tokens.
package googlecalendar

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/migueel15/SendaDesktopManager/core/internal/secrets"
)

var ErrNotConnected = errors.New("google calendar is not connected; run `senda calendar login`")

type storedToken struct {
	RefreshToken string `json:"refresh_token"`
}

type tokenSecrets interface {
	Save(string) error
	Load() (string, error)
	Delete() error
}

// TokenStore stores tokens in Secret Service. Path identifies the legacy file
// for migration and namespaces the keyring entry for this installation.
type TokenStore struct {
	Path    string
	secrets tokenSecrets
}

func (s TokenStore) backend() tokenSecrets {
	if s.secrets != nil {
		return s.secrets
	}
	path, _ := filepath.Abs(s.Path)
	sum := sha256.Sum256([]byte(path))
	return secretService{account: hex.EncodeToString(sum[:])}
}

// Save never falls back to a plaintext file. Remove legacy data only after the
// keyring has confirmed the write.
func (s TokenStore) Save(token string) error {
	if token == "" {
		return errors.New("cannot store an empty Google token")
	}
	if err := s.backend().Save(token); err != nil {
		return err
	}
	return s.deleteLegacy()
}

func (s TokenStore) Load() (string, error) {
	token, err := s.backend().Load()
	if err == nil {
		if err := s.deleteLegacy(); err != nil {
			return "", err
		}
		return token, nil
	}
	if !errors.Is(err, ErrNotConnected) {
		return "", err
	}
	// Migrate existing installations without requiring another Google login.
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
	var old storedToken
	if err := json.Unmarshal(data, &old); err != nil {
		return "", fmt.Errorf("invalid legacy Google token file: %w", err)
	}
	if old.RefreshToken == "" {
		return "", ErrNotConnected
	}
	if err := s.Save(old.RefreshToken); err != nil {
		return "", err
	}
	return old.RefreshToken, nil
}

func (s TokenStore) deleteLegacy() error {
	err := os.Remove(s.Path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	return err
}

func (s TokenStore) Delete() error {
	if err := s.backend().Delete(); err != nil {
		return err
	}
	return s.deleteLegacy()
}

type secretService struct{ account string }

func (s secretService) entry() secrets.Keyring {
	return secrets.Keyring{
		Label:      "Senda Google Calendar",
		Attributes: []string{"application", "senda", "account", s.account, "type", "google-calendar-refresh-token"},
	}
}

func keyringError(err error) error {
	if errors.Is(err, secrets.ErrNotFound) {
		return ErrNotConnected
	}
	if err != nil {
		return errors.New("Google Calendar keyring unavailable: install libsecret (secret-tool) and unlock a password-protected Secret Service keyring, such as GNOME Keyring or compatible KWallet")
	}
	return nil
}

func (s secretService) Save(token string) error { return keyringError(s.entry().Save(token)) }
func (s secretService) Load() (string, error) {
	token, err := s.entry().Load()
	return token, keyringError(err)
}
func (s secretService) Delete() error { return keyringError(s.entry().Delete()) }
