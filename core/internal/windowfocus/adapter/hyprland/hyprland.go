package hyprland

import (
	"context"
	"fmt"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
)

type Backend struct {
	hypr hyprctl.Client
}

func New() Backend {
	return Backend{hypr: hyprctl.New(nil)}
}

func (backend Backend) FocusClass(ctx context.Context, class string) error {
	windows, err := backend.hypr.Windows(ctx)
	if err != nil {
		return fmt.Errorf("list Hyprland clients: %w", err)
	}
	for _, candidate := range windows {
		if !strings.EqualFold(candidate.Class, class) {
			continue
		}
		if candidate.Address == "" {
			return fmt.Errorf("Hyprland client with class %q has no address", class)
		}
		if err := backend.hypr.FocusWindow(ctx, candidate.Address); err != nil {
			return fmt.Errorf("focus Hyprland client with class %q: %w", class, err)
		}
		return nil
	}
	return fmt.Errorf("no Hyprland client found with class %q", class)
}
