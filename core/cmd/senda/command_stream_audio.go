package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

type streamAudioState struct {
	NullSinkModuleID string `json:"nullSinkModuleId"`
	LoopbackModuleID string `json:"loopbackModuleId"`
	TargetSink       string `json:"targetSink"`
}

var streamAudioCmd = &cobra.Command{
	Use:   "stream-audio",
	Short: "Manage a virtual audio sink for app streaming",
}

var streamAudioOnCmd = &cobra.Command{
	Use:   "on",
	Short: "Enable stream audio routing",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		return runStreamAudioAction(cmd, turnStreamAudioOn)
	},
}

var streamAudioOffCmd = &cobra.Command{
	Use:   "off",
	Short: "Disable stream audio routing",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		return runStreamAudioAction(cmd, turnStreamAudioOff)
	},
}

var streamAudioStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Show stream audio routing status",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		return runStreamAudioAction(cmd, streamAudioStatus)
	},
}

func init() {
	streamAudioCmd.AddCommand(streamAudioOnCmd)
	streamAudioCmd.AddCommand(streamAudioOffCmd)
	streamAudioCmd.AddCommand(streamAudioStatusCmd)
}

func runStreamAudioAction(cmd *cobra.Command, action func() error) error {
	if err := action(); err != nil {
		cmd.SilenceUsage = true
		return err
	}
	return nil
}

func turnStreamAudioOn() error {
	if _, err := os.Stat(streamAudioStatePath()); err == nil {
		fmt.Println("stream audio already enabled")
		return nil
	} else if !os.IsNotExist(err) {
		return err
	}

	defaultSink, err := runStreamAudioCommand("pactl", "get-default-sink")
	if err != nil {
		return err
	}
	defaultSink = strings.TrimSpace(defaultSink)
	if defaultSink == "" {
		return fmt.Errorf("pactl returned an empty default sink")
	}

	nullID, err := runStreamAudioCommand(
		"pactl",
		"load-module",
		"module-null-sink",
		"sink_name=stream_sink",
		"sink_properties=device.description=Stream_Audio",
	)
	if err != nil {
		return err
	}
	nullID = strings.TrimSpace(nullID)

	loopID, err := runStreamAudioCommand(
		"pactl",
		"load-module",
		"module-loopback",
		"source=stream_sink.monitor",
		"sink="+defaultSink,
		"latency_msec=30",
	)
	if err != nil {
		_, _ = runStreamAudioCommand("pactl", "unload-module", nullID)
		return err
	}
	loopID = strings.TrimSpace(loopID)

	state := streamAudioState{
		NullSinkModuleID: nullID,
		LoopbackModuleID: loopID,
		TargetSink:       defaultSink,
	}

	if err := saveStreamAudioState(state); err != nil {
		_, _ = runStreamAudioCommand("pactl", "unload-module", loopID)
		_, _ = runStreamAudioCommand("pactl", "unload-module", nullID)
		return err
	}

	fmt.Println("stream audio enabled")
	fmt.Println("Sunshine audio device: stream_sink.monitor")
	fmt.Println("Loopback target:", defaultSink)
	fmt.Println("Move the app you want to share to Stream_Audio using pavucontrol.")
	return nil
}

func turnStreamAudioOff() error {
	state, err := loadStreamAudioState()
	if err != nil {
		return err
	}

	if state.LoopbackModuleID != "" {
		_, _ = runStreamAudioCommand("pactl", "unload-module", state.LoopbackModuleID)
	}

	if state.NullSinkModuleID != "" {
		_, _ = runStreamAudioCommand("pactl", "unload-module", state.NullSinkModuleID)
	}

	_ = os.Remove(streamAudioStatePath())

	fmt.Println("stream audio disabled")
	return nil
}

func streamAudioStatus() error {
	if _, err := os.Stat(streamAudioStatePath()); err == nil {
		state, _ := loadStreamAudioState()
		fmt.Println("stream audio enabled")
		fmt.Println("target sink:", state.TargetSink)
		return nil
	} else if !os.IsNotExist(err) {
		return err
	}

	fmt.Println("stream audio disabled")
	return nil
}

func runStreamAudioCommand(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s %v failed: %w\n%s", name, args, err, string(out))
	}
	return string(out), nil
}

func streamAudioStatePath() string {
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		runtimeDir = os.TempDir()
	}
	return filepath.Join(runtimeDir, "stream-audio-state.json")
}

func saveStreamAudioState(state streamAudioState) error {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(streamAudioStatePath(), data, 0o600)
}

func loadStreamAudioState() (streamAudioState, error) {
	var state streamAudioState
	data, err := os.ReadFile(streamAudioStatePath())
	if err != nil {
		return state, err
	}
	err = json.Unmarshal(data, &state)
	return state, err
}
