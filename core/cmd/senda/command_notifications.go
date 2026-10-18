package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"syscall"

	"github.com/spf13/cobra"
)

// notificationsCmd is registered by main.go with:
// rootCmd.AddCommand(notificationsCmd)
var notificationsCmd = newNotificationsCmd()

func newNotificationsCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "notifications",
		Short: "List and dismiss pending notifications",
	}
	cmd.AddCommand(
		&cobra.Command{
			Use:   "list",
			Short: "List pending notifications",
			Args:  cobra.NoArgs,
			RunE: func(cmd *cobra.Command, args []string) error {
				result, err := callNotificationsIPC(cmd, "listUnread")
				if err != nil {
					return err
				}
				data, err := decodeNotificationsJSON(result)
				if err != nil {
					return fmt.Errorf("notifications IPC returned invalid JSON")
				}

				var pretty bytes.Buffer
				if err := json.Indent(&pretty, data, "", "  "); err != nil {
					return fmt.Errorf("notifications IPC returned invalid JSON")
				}
				if _, err := cmd.OutOrStdout().Write(append(pretty.Bytes(), '\n')); err != nil {
					return fmt.Errorf("could not write notifications output: %w", err)
				}
				return nil
			},
		},
		&cobra.Command{
			Use:   "dismiss <id>",
			Short: "Dismiss a pending notification by ID",
			Args:  cobra.ExactArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				result, err := callNotificationsIPC(cmd, "dismiss", args[0])
				if err != nil {
					return err
				}
				var dismissed bool
				if err := json.Unmarshal([]byte(strings.TrimSpace(result)), &dismissed); err != nil {
					return fmt.Errorf("notifications IPC returned an invalid dismiss result")
				}
				if dismissed {
					_, err = fmt.Fprintln(cmd.OutOrStdout(), "Notification dismissed.")
					return err
				}
				_, err = fmt.Fprintln(cmd.OutOrStdout(), "Notification not found or already dismissed.")
				return err
			},
		},
		&cobra.Command{
			Use:   "clear",
			Short: "Dismiss all pending notifications",
			Args:  cobra.NoArgs,
			RunE: func(cmd *cobra.Command, args []string) error {
				result, err := callNotificationsIPC(cmd, "dismissAll")
				if err != nil {
					return err
				}
				var dismissed int
				if err := json.Unmarshal([]byte(strings.TrimSpace(result)), &dismissed); err != nil {
					return fmt.Errorf("notifications IPC returned an invalid clear result")
				}
				_, err = fmt.Fprintf(cmd.OutOrStdout(), "Dismissed %d notification(s).\n", dismissed)
				return err
			},
		},
	)
	return cmd
}

func callNotificationsIPC(cmd *cobra.Command, function string, args ...string) (string, error) {
	return callShellIPC(cmd, "notifications", function, args...)
}

// callShellIPC calls a function on an IpcHandler target of the running shell.
func callShellIPC(cmd *cobra.Command, target string, function string, args ...string) (string, error) {
	pid := readPidData()
	if pid <= 0 || !isProcessRunning(pid) {
		cmd.SilenceUsage = true
		return "", fmt.Errorf("Senda shell is not running; start it with `senda shell run` and try again")
	}

	processArgs := []string{"ipc", "--pid", fmt.Sprint(pid), "call", target, function}
	processArgs = append(processArgs, args...)
	process := exec.CommandContext(cmd.Context(), "qs", processArgs...)
	output, err := process.Output()
	if err != nil {
		cmd.SilenceUsage = true
		if _, ok := err.(*exec.Error); ok {
			return "", fmt.Errorf("Quickshell IPC is unavailable: `qs` could not be started")
		}
		return "", fmt.Errorf("could not call %s IPC on Senda shell PID %d; confirm its IPC target is available", target, pid)
	}
	return string(output), nil
}

func isProcessRunning(pid int) bool {
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	return process.Signal(syscall.Signal(0)) == nil
}

func decodeNotificationsJSON(output string) ([]byte, error) {
	data := []byte(strings.TrimSpace(output))
	if len(data) == 0 {
		return nil, fmt.Errorf("empty response")
	}
	var notifications []json.RawMessage
	if data[0] == '[' && json.Unmarshal(data, &notifications) == nil {
		return data, nil
	}

	// Quickshell may serialize a QML string as a JSON string. Decode that
	// wrapper once, then validate that the string contains the expected array.
	var serialized string
	if err := json.Unmarshal(data, &serialized); err != nil {
		return nil, err
	}
	data = []byte(serialized)
	if len(data) == 0 || data[0] != '[' {
		return nil, fmt.Errorf("response is not a JSON array")
	}
	if err := json.Unmarshal(data, &notifications); err != nil {
		return nil, err
	}
	return data, nil
}
