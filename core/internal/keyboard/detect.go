// Package keyboard identifies physical keyboards controlled by Hyprland.
package keyboard

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type Device struct {
	Event    string   `json:"event"`
	Name     string   `json:"name"`
	Hyprland []string `json:"hyprland"`
	Included bool     `json:"included"`
	Reason   string   `json:"reason"`
}

type Detector struct {
	SysInput   string
	UdevData   string
	Properties func(string) ([]byte, error)
}

func DefaultDetector() Detector {
	return Detector{SysInput: "/sys/class/input", UdevData: "/run/udev/data", Properties: func(event string) ([]byte, error) {
		return exec.Command("udevadm", "info", "-q", "property", "-n", "/dev/input/"+event).Output()
	}}
}

// Detect matches the input devices with the Hyprland keyboard names.
func (d Detector) Detect(keyboards []string) ([]Device, error) {
	events, err := filepath.Glob(filepath.Join(d.SysInput, "event*"))
	if err != nil {
		return nil, err
	}
	result := make([]Device, 0, len(events))
	for _, path := range events {
		event := filepath.Base(path)
		target, err := filepath.EvalSymlinks(path)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", event, err)
		}
		name, err := os.ReadFile(filepath.Join(path, "device/name"))
		if err != nil {
			return nil, fmt.Errorf("%s name: %w", event, err)
		}
		dev, err := os.ReadFile(filepath.Join(path, "dev"))
		if err != nil {
			return nil, fmt.Errorf("%s dev: %w", event, err)
		}
		props, err := os.ReadFile(filepath.Join(d.UdevData, "c"+strings.TrimSpace(string(dev))))
		if err != nil && d.Properties != nil {
			props, err = d.Properties(event)
		}
		if err != nil {
			return nil, fmt.Errorf("%s udev: %w", event, err)
		}
		item := Device{Event: event, Name: strings.TrimRight(string(name), "\r\n")}
		if strings.Contains(filepath.ToSlash(target), "/devices/virtual/") {
			item.Reason = "dispositivo virtual"
		} else if !hasKeyboardProperty(props) {
			item.Reason = "udev no lo identifica como teclado"
		} else {
			base := strings.ReplaceAll(strings.ToLower(item.Name), " ", "-")
			pattern := regexp.MustCompile("^" + regexp.QuoteMeta(base) + "(?:-[0-9]+)?$")
			for _, keyboard := range keyboards {
				if pattern.MatchString(keyboard) {
					item.Hyprland = append(item.Hyprland, keyboard)
				}
			}
			sort.Strings(item.Hyprland)
			if len(item.Hyprland) == 0 {
				item.Reason = "sin correspondencia en Hyprland"
			} else {
				item.Included = true
				item.Reason = "teclado físico"
			}
		}
		result = append(result, item)
	}
	return result, nil
}

func hasKeyboardProperty(data []byte) bool {
	for _, line := range strings.Split(string(data), "\n") {
		if strings.TrimPrefix(strings.TrimSpace(line), "E:") == "ID_INPUT_KEYBOARD=1" {
			return true
		}
	}
	return false
}
