package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestSTTCommandHelpAndArgs(t *testing.T) {
	cmd := sttCmd()
	var output bytes.Buffer
	cmd.SetOut(&output)
	cmd.SetArgs([]string{"--help"})
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"toggle", "cancel", "status", "session", "models", "shortcut", "runtime"} {
		if !strings.Contains(output.String(), name) {
			t.Errorf("help is missing %s", name)
		}
	}
	for _, args := range [][]string{{"toggle", "extra"}, {"models", "install"}, {"shortcut", "set"}, {"runtime", "install", "extra"}} {
		cmd := sttCmd()
		cmd.SetOut(&output)
		cmd.SetErr(&output)
		cmd.SetArgs(args)
		if err := cmd.Execute(); err == nil {
			t.Fatalf("accepted invalid args %v: %v", args, err)
		}
	}
}
