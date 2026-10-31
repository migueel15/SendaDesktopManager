package secrets

import (
	"bytes"
	"context"
	"errors"
	"os/exec"
	"strings"
	"time"
)

var (
	// ErrNotFound means the keyring answered and has no such entry.
	ErrNotFound = errors.New("secret not found")
	// ErrUnavailable hides the diagnostics of secret-tool, which could leak data.
	ErrUnavailable = errors.New("keyring unavailable")
)

// Keyring is one Secret Service entry, reached through secret-tool. Values go
// through stdin, never command arguments or error messages.
type Keyring struct {
	Label      string
	Attributes []string
}

func (k Keyring) run(action, value string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	args := []string{action}
	if action == "store" {
		args = append(args, "--label="+k.Label)
	}
	args = append(args, k.Attributes...)
	cmd := exec.CommandContext(ctx, "secret-tool", args...)
	if action == "store" {
		cmd.Stdin = strings.NewReader(value)
	}
	var output, diagnostic bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &diagnostic
	if err := cmd.Run(); err != nil {
		// libsecret reports a missing match with exit 1 and no diagnostic.
		var exit *exec.ExitError
		if ctx.Err() == nil && errors.As(err, &exit) && exit.ExitCode() == 1 && diagnostic.Len() == 0 && action != "store" {
			return "", ErrNotFound
		}
		return "", ErrUnavailable
	}
	return output.String(), nil
}

func (k Keyring) Save(value string) error {
	_, err := k.run("store", value)
	return err
}

func (k Keyring) Load() (string, error) {
	value, err := k.run("lookup", "")
	if err != nil {
		return "", err
	}
	if value == "" {
		return "", ErrNotFound
	}
	return value, nil
}

func (k Keyring) Delete() error {
	_, err := k.run("clear", "")
	if errors.Is(err, ErrNotFound) {
		return nil
	}
	return err
}
