package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/discordbridge"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

func discordCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "discord <action> [arguments]",
		Short: "Control the local Discord voice bridge",
		Args: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return fmt.Errorf("discord requires an action")
			}
			switch args[0] {
			case "set-user-volume", "set-user-mute":
				if len(args) != 3 {
					return fmt.Errorf("%s requires a user ID and value", args[0])
				}
			case "reset-user":
				if len(args) != 2 {
					return fmt.Errorf("%s requires a user ID", args[0])
				}
			default:
				if len(args) != 1 {
					return fmt.Errorf("%s does not accept arguments", args[0])
				}
			}
			return nil
		},
		ValidArgs: []string{"status", "connect", "authorize", "mute", "unmute", "toggle-mute", "deafen", "undeafen", "toggle-deafen", "leave", "set-user-volume", "set-user-mute", "reset-user", "shutdown", "stop"},
		RunE: func(cmd *cobra.Command, args []string) error {
			if args[0] == "stop" {
				return discordbridge.Stop(discordbridge.SocketPath(), 3*time.Second)
			}
			script, err := discordBridgePath()
			if err != nil {
				return err
			}
			python, err := exec.LookPath("python3")
			if err != nil {
				return fmt.Errorf("python3 is required for the Discord bridge: %w", err)
			}
			processArgs := append([]string{script}, args...)
			process := exec.CommandContext(cmd.Context(), python, processArgs...)
			process.Stdout = os.Stdout
			process.Stderr = os.Stderr
			return process.Run()
		},
	}
	return cmd
}

func discordBridgePath() (string, error) {
	if override := paths.Setting("SENDA_DISCORD_BRIDGE"); override != "" {
		return override, nil
	}
	candidates := []string{paths.DiscordBridgeScript()}
	if executable, err := os.Executable(); err == nil {
		dir := filepath.Dir(executable)
		candidates = append(candidates, filepath.Join(dir, "discord-bridge.py"), filepath.Join(dir, "..", "scripts", "discord-bridge.py"))
	}
	if workingDir, err := os.Getwd(); err == nil {
		candidates = append(candidates, filepath.Join(workingDir, "core", "scripts", "discord-bridge.py"), filepath.Join(workingDir, "scripts", "discord-bridge.py"))
	}
	for _, candidate := range candidates {
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("cannot find discord-bridge.py; set SENDA_DISCORD_BRIDGE to its path")
}
