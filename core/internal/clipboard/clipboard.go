// Package clipboard keeps a local history of copied text. A `wl-paste --watch`
// process hands every change to `senda clipboard store`, one process per copy,
// so the history file is locked around each change.
package clipboard

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode/utf8"

	"github.com/migueel15/SendaDesktopManager/core/internal/instance"
)

const (
	KeyEnabled = "SENDA_CLIPBOARD_ENABLED"
	KeyMax     = "SENDA_CLIPBOARD_MAX"
	DefaultMax = 100
	LimitMax   = 1000
	// MaxTextBytes leaves out huge selections, which would slow every search.
	MaxTextBytes = 1 << 20
	instanceName = "net.dorlab.Senda.ClipboardWatcher"
)

// ErrNotFound means the id is not in the history.
var ErrNotFound = errors.New("entrada no encontrada en el historial")

// Entry is one copied text. Its id comes from the text, so it stays valid while
// the entry moves. Entries are kept newest first.
type Entry struct {
	ID       string    `json:"id"`
	Text     string    `json:"text"`
	CopiedAt time.Time `json:"copiedAt"`
}

// Settings holds the preferences the history reads on every copy, so changes
// apply without restarting the watcher.
type Settings struct {
	Enabled bool
	Max     int
}

// ValidMax reports whether value is an allowed maximum number of entries.
func ValidMax(value string) bool {
	number, err := strconv.Atoi(value)
	return err == nil && number >= 1 && number <= LimitMax
}

// LoadSettings substitutes defaults for empty or invalid values.
func LoadSettings(values map[string]string) Settings {
	settings := Settings{Enabled: values[KeyEnabled] != "false", Max: DefaultMax}
	if ValidMax(values[KeyMax]) {
		settings.Max, _ = strconv.Atoi(values[KeyMax])
	}
	return settings
}

// Store is the history file, private to the user.
type Store struct{ Path string }

// locked runs change on the entries and saves what it returns.
func (s Store) locked(change func([]Entry) []Entry) error {
	if err := os.MkdirAll(filepath.Dir(s.Path), 0o700); err != nil {
		return err
	}
	lock, err := os.OpenFile(s.Path+".lock", os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	entries, err := s.List()
	if err != nil {
		return err
	}
	return s.write(change(entries))
}

// List returns the entries, newest first.
func (s Store) List() ([]Entry, error) {
	data, err := os.ReadFile(s.Path)
	if errors.Is(err, fs.ErrNotExist) {
		return []Entry{}, nil
	}
	if err != nil {
		return nil, err
	}
	entries := []Entry{}
	if err := json.Unmarshal(data, &entries); err != nil {
		return nil, err
	}
	return entries, nil
}

func (s Store) write(entries []Entry) error {
	data, err := json.Marshal(entries)
	if err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(s.Path), ".clipboard-*")
	if err != nil {
		return err
	}
	defer os.Remove(temporary.Name())
	_, err = temporary.Write(data)
	if closeErr := temporary.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(temporary.Name(), s.Path)
}

// Add puts text first, removes an earlier copy of it and drops the oldest
// entries over max. Blank, binary and oversized text is ignored.
func (s Store) Add(text string, max int, now time.Time) error {
	if strings.TrimSpace(text) == "" || len(text) > MaxTextBytes || !utf8.ValidString(text) {
		return nil
	}
	sum := sha256.Sum256([]byte(text))
	id := hex.EncodeToString(sum[:6])
	return s.locked(func(entries []Entry) []Entry {
		kept := []Entry{{ID: id, Text: text, CopiedAt: now}}
		for _, entry := range entries {
			if entry.ID != id && len(kept) < max {
				kept = append(kept, entry)
			}
		}
		return kept
	})
}

// Clear empties the history.
func (s Store) Clear() error {
	return s.locked(func([]Entry) []Entry { return []Entry{} })
}

// Find returns the entry with id.
func (s Store) Find(id string) (Entry, error) {
	entries, err := s.List()
	if err != nil {
		return Entry{}, err
	}
	for _, entry := range entries {
		if entry.ID == id {
			return entry, nil
		}
	}
	return Entry{}, ErrNotFound
}

// Capture stores what wl-paste hands to its watch command. Only CLIPBOARD_STATE
// "data" is read: "sensitive" marks what password managers copy, and it is never
// saved.
func Capture(store Store, state string, input io.Reader, settings Settings, now time.Time) error {
	if !settings.Enabled || state != "data" {
		return nil
	}
	data, err := io.ReadAll(io.LimitReader(input, MaxTextBytes+1))
	if err != nil {
		return err
	}
	return store.Add(string(data), settings.Max, now)
}

// Restore puts text back on the clipboard. The watcher then moves it to the top.
func Restore(ctx context.Context, text string) error {
	// wl-copy stays in the background; a nil stdout keeps Run from waiting for it.
	command := exec.CommandContext(ctx, "wl-copy")
	command.Stdin = strings.NewReader(text)
	return command.Run()
}

// Watch runs executable with the given arguments on each text copy until ctx
// ends or a newer watcher replaces this one.
func Watch(ctx context.Context, executable string, args ...string) error {
	replaced, err := instance.Claim(ctx, instanceName)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	go func() {
		<-replaced
		cancel()
	}()
	command := exec.CommandContext(ctx, "wl-paste", append([]string{"--type", "text", "--watch", executable}, args...)...)
	command.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGTERM}
	err = command.Run()
	if ctx.Err() != nil {
		return nil
	}
	return err
}
