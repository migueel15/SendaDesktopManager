package setup

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/discordbridge"
)

// SystemPacman is the Pacman implementation that runs the real pacman and sudo.
type SystemPacman struct{}

// Known reports whether pacman knows pkg in its sync databases. A non-zero
// exit status means unknown; other failures are returned as errors.
func (SystemPacman) Known(pkg string) (bool, error) {
	err := exec.Command("pacman", "-Si", pkg).Run()
	if err == nil {
		return true, nil
	}
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return false, nil
	}
	return false, fmt.Errorf("consultar %s con pacman: %w", pkg, err)
}

// Install runs sudo pacman -S --needed with the terminal attached, so the
// user can read the prompts and type the password.
func (SystemPacman) Install(pkgs []string) error {
	args := append([]string{"pacman", "-S", "--needed"}, pkgs...)
	cmd := exec.Command("sudo", args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// StartShell restarts Quickshell: it stops any instance already running, and
// the Discord bridge, so the freshly installed files are loaded, then starts
// `exe shell run` detached from this process, the same way update restarts it.
// Quickshell starts the installed bridge again. It does not wait for the child.
func StartShell(exe string) error {
	if err := exec.Command(exe, "shell", "kill").Run(); err != nil {
		return fmt.Errorf("detener Quickshell: %w", err)
	}
	if err := discordbridge.Stop(discordbridge.SocketPath(), 3*time.Second); err != nil {
		fmt.Fprintln(os.Stderr, "aviso:", err)
	}

	shell := exec.Command(exe, "shell", "run")
	shell.Stdin = nil
	shell.Stdout = nil
	shell.Stderr = nil
	shell.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return shell.Start()
}
