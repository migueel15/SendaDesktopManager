// Package brightness controls the internal panel through brightnessctl.
package brightness

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

const sysBacklightDir = "/sys/class/backlight"

// Available reports whether the machine has a screen with a backlight.
func Available() bool {
	return hasBacklight(sysBacklightDir)
}

func hasBacklight(dir string) bool {
	entries, err := os.ReadDir(dir)
	return err == nil && len(entries) > 0
}

// Get returns the current backlight percentage.
func Get(ctx context.Context) (int, error) {
	return run(ctx, "info")
}

// Change moves the backlight by step percent and returns the new percentage.
// The minimum keeps the panel from turning completely off.
func Change(ctx context.Context, step int) (int, error) {
	sign := "+"
	if step < 0 {
		sign = "-"
		step = -step
	}
	return run(ctx, "--min-value=1", "set", fmt.Sprintf("%d%%%s", step, sign))
}

func run(ctx context.Context, args ...string) (int, error) {
	args = append([]string{"-m", "-c", "backlight"}, args...)
	output, err := exec.CommandContext(ctx, "brightnessctl", args...).Output()
	if err != nil {
		return 0, fmt.Errorf("brightnessctl: %w", err)
	}
	return parsePercent(string(output))
}

// parsePercent reads the machine format: device,class,current,percent%,max.
func parsePercent(output string) (int, error) {
	fields := strings.Split(strings.TrimSpace(output), ",")
	if len(fields) < 5 {
		return 0, fmt.Errorf("unexpected brightnessctl output %q", output)
	}
	percent, err := strconv.Atoi(strings.TrimSuffix(fields[3], "%"))
	if err != nil {
		return 0, fmt.Errorf("unexpected brightnessctl output %q", output)
	}
	return percent, nil
}
