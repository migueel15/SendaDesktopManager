package windowfocus

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/windowfocus/adapter/hyprland"
)

type Backend interface {
	FocusClass(ctx context.Context, class string) error
}

func DetectBackend() (Backend, error) {
	currentDesktop := strings.ToLower(os.Getenv("XDG_CURRENT_DESKTOP") + ":" + os.Getenv("DESKTOP_SESSION"))
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "" || strings.Contains(currentDesktop, "hyprland") {
		return hyprland.New(), nil
	}

	if currentDesktop == ":" {
		currentDesktop = "unknown"
	}
	return nil, fmt.Errorf("window focus is not supported for compositor %q", currentDesktop)
}

func FocusClass(ctx context.Context, backend Backend, class string) error {
	class = strings.TrimSpace(class)
	if class == "" {
		return fmt.Errorf("window class cannot be empty")
	}
	return backend.FocusClass(ctx, class)
}
