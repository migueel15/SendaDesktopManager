package hyprland

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

type Backend struct {
	command func(context.Context, ...string) ([]byte, error)
}

type client struct {
	Address string `json:"address"`
	Class   string `json:"class"`
}

func New() Backend {
	return Backend{command: runHyprctl}
}

func (backend Backend) FocusClass(ctx context.Context, class string) error {
	output, err := backend.command(ctx, "-j", "clients")
	if err != nil {
		return fmt.Errorf("list Hyprland clients: %w", err)
	}

	var clients []client
	if err := json.Unmarshal(output, &clients); err != nil {
		return fmt.Errorf("parse Hyprland clients: %w", err)
	}

	for _, candidate := range clients {
		if !strings.EqualFold(candidate.Class, class) {
			continue
		}
		if candidate.Address == "" {
			return fmt.Errorf("Hyprland client with class %q has no address", class)
		}
		if _, err := strconv.ParseUint(candidate.Address, 0, 64); err != nil {
			return fmt.Errorf("Hyprland client with class %q has invalid address %q", class, candidate.Address)
		}
		dispatch := fmt.Sprintf(`hl.dsp.focus({ window = "address:%s" })`, candidate.Address)
		if _, err := backend.command(ctx, "dispatch", dispatch); err != nil {
			return fmt.Errorf("focus Hyprland client with class %q: %w", class, err)
		}
		return nil
	}

	return fmt.Errorf("no Hyprland client found with class %q", class)
}

func runHyprctl(ctx context.Context, args ...string) ([]byte, error) {
	output, err := exec.CommandContext(ctx, "hyprctl", args...).CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("hyprctl %s failed: %w: %s", strings.Join(args, " "), err, strings.TrimSpace(string(output)))
	}
	return output, nil
}
