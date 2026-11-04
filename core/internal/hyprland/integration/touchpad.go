package integration

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// touchpadNames is replaced in tests.
var touchpadNames = func() []string { return detectTouchpads("/sys/class/input", "/run/udev/data") }

var nonName = regexp.MustCompile(`\s+`)

// detectTouchpads returns the Hyprland names of the touchpads, which udev
// marks with ID_INPUT_TOUCHPAD=1. Hyprland names a device after the kernel
// name, in lowercase and with dashes instead of spaces.
func detectTouchpads(sysInput, udevData string) []string {
	events, _ := filepath.Glob(filepath.Join(sysInput, "event*"))
	seen := map[string]bool{}
	names := []string{}
	for _, path := range events {
		if target, err := filepath.EvalSymlinks(path); err != nil || strings.Contains(filepath.ToSlash(target), "/devices/virtual/") {
			continue
		}
		dev, err := os.ReadFile(filepath.Join(path, "dev"))
		if err != nil {
			continue
		}
		props, err := os.ReadFile(filepath.Join(udevData, "c"+strings.TrimSpace(string(dev))))
		if err != nil || !strings.Contains("\n"+string(props), "\nE:ID_INPUT_TOUCHPAD=1\n") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(path, "device/name"))
		if err != nil {
			continue
		}
		name := nonName.ReplaceAllString(strings.ToLower(strings.TrimSpace(string(raw))), "-")
		if name != "" && !seen[name] {
			seen[name] = true
			names = append(names, name)
		}
	}
	sort.Strings(names)
	return names
}
