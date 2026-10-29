// Package setup performs the first-time installation of Senda on a system:
// it checks the platform, installs missing Arch packages, creates the user
// configuration and installs the Quickshell files from the latest release.
package setup

import (
	"bufio"
	"errors"
	"fmt"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"io"
	"strings"
)

// CheckNotRoot refuses to run as root, because setup writes into the user's
// home directories and must not leave root-owned files there.
func CheckNotRoot(euid int) error {
	if euid == 0 {
		return errors.New("no ejecutes senda setup como root")
	}
	return nil
}

// CheckDistribution requires ID=arch in the os-release content read from r.
func CheckDistribution(r io.Reader) error {
	id, err := osReleaseID(r)
	if err != nil {
		return fmt.Errorf("leer /etc/os-release: %w", err)
	}
	if id != "arch" {
		return errors.New("solo se soporta Arch Linux en esta versión")
	}
	return nil
}

// osReleaseID returns the unquoted ID value, or an empty string when absent.
func osReleaseID(r io.Reader) (string, error) {
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok || strings.TrimSpace(key) != "ID" {
			continue
		}
		return strings.Trim(strings.TrimSpace(value), `"'`), nil
	}
	return "", scanner.Err()
}

// CheckCompositor requires a Hyprland session, detected either through
// XDG_CURRENT_DESKTOP or through the Hyprland instance signature.
func CheckCompositor(getenv func(string) string) error {
	desktop := strings.ToLower(getenv("XDG_CURRENT_DESKTOP"))
	if strings.Contains(desktop, "hyprland") || hyprctl.InSessionEnv(getenv) {
		return nil
	}
	return errors.New("solo se soporta Hyprland; ejecuta senda setup dentro de una sesión de Hyprland")
}
