package hyprctl

import (
	"bufio"
	"context"
	"errors"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// EventConfigReloaded is the event Hyprland emits after a configuration reload.
const EventConfigReloaded = "configreloaded"

// EventSocket returns the path of the event socket of the running session.
func EventSocket() (string, error) {
	signature, runtime := os.Getenv(SignatureEnv), os.Getenv("XDG_RUNTIME_DIR")
	if signature == "" || runtime == "" {
		return "", errors.New("no hay una sesión de Hyprland")
	}
	return filepath.Join(runtime, "hypr", signature, ".socket2.sock"), nil
}

// WatchEvents calls handle for every event until ctx ends, reconnecting
// every second when the socket closes. It returns at once outside Hyprland.
func WatchEvents(ctx context.Context, handle func(name, data string)) {
	path, err := EventSocket()
	if err != nil {
		return
	}
	for ctx.Err() == nil {
		if conn, err := net.Dial("unix", path); err == nil {
			stop := context.AfterFunc(ctx, func() { conn.Close() })
			scanner := bufio.NewScanner(conn)
			for scanner.Scan() {
				name, data, _ := strings.Cut(scanner.Text(), ">>")
				handle(name, data)
			}
			stop()
			conn.Close()
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(time.Second):
		}
	}
}
