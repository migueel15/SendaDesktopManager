// Package discordbridge manages the Discord voice bridge daemon started by
// scripts/discord-bridge.py.
package discordbridge

import (
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

// SocketPath is the control socket of the bridge, the same path the Python
// script listens on.
func SocketPath() string {
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if runtime == "" {
		runtime = fmt.Sprintf("/run/user/%d", os.Getuid())
	}
	return filepath.Join(runtime, "senda-discord.sock")
}

// Stop terminates the bridge listening on socket, whatever script started it,
// so the next `senda discord connect` starts the installed one. The process is
// found through the socket's peer credentials, because an older bridge may not
// understand the shutdown action. It returns nil when no bridge is running.
func Stop(socket string, timeout time.Duration) error {
	pid, err := listenerPID(socket)
	if err != nil || pid <= 0 {
		return nil
	}
	if err := syscall.Kill(pid, syscall.SIGTERM); err != nil {
		if errors.Is(err, syscall.ESRCH) {
			return nil
		}
		return fmt.Errorf("detener el puente de Discord (pid %d): %w", pid, err)
	}
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if err := syscall.Kill(pid, 0); errors.Is(err, syscall.ESRCH) {
			return nil
		}
		time.Sleep(50 * time.Millisecond)
	}
	return fmt.Errorf("el puente de Discord (pid %d) no se detuvo", pid)
}

// listenerPID returns the pid of the process listening on socket.
func listenerPID(socket string) (int, error) {
	conn, err := net.DialTimeout("unix", socket, 200*time.Millisecond)
	if err != nil {
		return 0, err
	}
	defer conn.Close()

	raw, err := conn.(*net.UnixConn).SyscallConn()
	if err != nil {
		return 0, err
	}
	var cred *syscall.Ucred
	var credErr error
	if err := raw.Control(func(fd uintptr) {
		cred, credErr = syscall.GetsockoptUcred(int(fd), syscall.SOL_SOCKET, syscall.SO_PEERCRED)
	}); err != nil {
		return 0, err
	}
	if credErr != nil {
		return 0, credErr
	}
	return int(cred.Pid), nil
}
