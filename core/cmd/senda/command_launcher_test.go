package main

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func TestLauncherToggleIPC(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", dir)
	t.Setenv("PATH", dir)
	output := filepath.Join(dir, "args")
	t.Setenv("LAUNCHER_TEST_OUTPUT", output)
	if err := os.WriteFile(getPidFilePath(), []byte(strconv.Itoa(os.Getpid())), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "qs"), []byte("#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$LAUNCHER_TEST_OUTPUT\"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		args []string
		want string
	}{
		{[]string{"toggle"}, "call\nlauncher\ntoggle\n"},
		{[]string{"toggle", "--screen", "DP-2"}, "call\nlauncher\ntoggleOnScreen\nDP-2\n"},
	} {
		cmd := newLauncherCmd()
		cmd.SetArgs(tc.args)
		if err := cmd.Execute(); err != nil {
			t.Fatal(err)
		}
		got, err := os.ReadFile(output)
		if err != nil {
			t.Fatal(err)
		}
		prefix := "ipc\n--pid\n" + strconv.Itoa(os.Getpid()) + "\n"
		if string(got) != prefix+tc.want {
			t.Fatalf("arguments = %q, want %q", got, prefix+tc.want)
		}
	}
}

func TestLauncherToggleWithoutShell(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())
	cmd := newLauncherCmd()
	cmd.SetArgs([]string{"toggle"})
	cmd.SilenceErrors = true
	if err := cmd.Execute(); err == nil || !strings.Contains(err.Error(), "shell is not running") {
		t.Fatalf("expected unavailable shell error, got %v", err)
	}
}
