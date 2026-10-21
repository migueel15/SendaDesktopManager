// Package deliver transfers recognized text to the clipboard or focused window.
package deliver

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type deliverer struct{ run stt.Runner }

func New(run stt.Runner) stt.Deliverer { return &deliverer{run: run} }

func (d *deliverer) Deliver(ctx context.Context, text string, s stt.Settings) error {
	if strings.TrimSpace(text) == "" {
		return nil
	}
	if _, err := d.run(ctx, strings.NewReader(text), "wl-copy"); err != nil {
		return fmt.Errorf("copiar texto al portapapeles con wl-copy: %w", err)
	}
	if s.PasteMode != stt.PasteDirect {
		return nil
	}

	args := []string{"-M", "ctrl", "v", "-m", "ctrl"}
	active, err := d.run(ctx, nil, "hyprctl", "activewindow", "-j")
	if err == nil {
		var window struct {
			Class string `json:"class"`
		}
		if json.Unmarshal(active, &window) == nil && isTerminal(window.Class, s.Terminals) {
			args = []string{"-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"}
		}
	}
	if _, err := d.run(ctx, nil, "wtype", args...); err != nil {
		return fmt.Errorf("el texto permanece en el portapapeles, pero no se pudo pegar con wtype: %w", err)
	}
	return nil
}

func isTerminal(class string, terminals []string) bool {
	for _, terminal := range terminals {
		if strings.EqualFold(class, terminal) {
			return true
		}
	}
	return false
}
