package main

import (
	"encoding/json"
	"strings"

	"github.com/spf13/cobra"
)

func callShellIPCResult(cmd *cobra.Command, target, function string, args ...string) (string, error) {
	output, err := callShellIPC(cmd, target, function, args...)
	if err != nil {
		return "", err
	}
	return normalizeShellIPCResult(output), nil
}

func normalizeShellIPCResult(output string) string {
	output = strings.TrimSpace(output)
	var decoded string
	if json.Unmarshal([]byte(output), &decoded) == nil {
		return strings.TrimSpace(decoded)
	}
	return output
}
