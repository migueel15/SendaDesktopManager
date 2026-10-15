package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/spf13/cobra"
)

func discordCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:       "discord",
		Short:     "Control the local Discord voice bridge",
		Args:      cobra.ExactArgs(1),
		ValidArgs: []string{"status", "connect", "authorize", "mute", "unmute", "toggle-mute", "deafen", "undeafen", "toggle-deafen", "shutdown"},
		RunE: func(cmd *cobra.Command, args []string) error {
			script, err := discordBridgePath()
			if err != nil {
				return err
			}
			python, err := exec.LookPath("python3")
			if err != nil {
				return fmt.Errorf("python3 is required for the Discord bridge: %w", err)
			}
			process := exec.CommandContext(cmd.Context(), python, script, args[0])
			process.Stdout = os.Stdout
			process.Stderr = os.Stderr
			return process.Run()
		},
	}
	return cmd
}

func discordBridgePath() (string, error) {
	if override := os.Getenv("SENDA_DISCORD_BRIDGE"); override != "" {
		return override, nil
	}
	var candidates []string
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
