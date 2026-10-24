package main

import (
	"context"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/spf13/cobra"
)

func TestNormalizeShellIPCResult(t *testing.T) {
	for _, tc := range []struct{ input, want string }{{" \n", ""}, {`""`, ""}, {` " {\"ok\":true} " `, `{"ok":true}`}, {" true\n", "true"}, {`"\"nested\""`, `"nested"`}} {
		if got := normalizeShellIPCResult(tc.input); got != tc.want {
			t.Errorf("%q => %q, want %q", tc.input, got, tc.want)
		}
	}
}

func TestCallShellIPCResult(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", dir)
	cmd := &cobra.Command{}
	cmd.SetContext(context.Background())
	if _, err := callShellIPCResult(cmd, "theme", "reload"); err == nil {
		t.Fatal("expected unavailable shell error")
	}
	if err := os.WriteFile(getPidFilePath(), []byte(strconv.Itoa(os.Getpid())), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
	for _, tc := range []struct {
		script, want string
		fail         bool
	}{{"printf '  '", "", false}, {`printf '%s\n' '"done"'`, "done", false}, {"exit 1", "", true}} {
		if err := os.WriteFile(filepath.Join(dir, "qs"), []byte("#!/bin/sh\n"+tc.script+"\n"), 0700); err != nil {
			t.Fatal(err)
		}
		got, err := callShellIPCResult(cmd, "theme", "reload")
		if (err != nil) != tc.fail || got != tc.want {
			t.Fatalf("got %q, %v; want %q, fail=%v", got, err, tc.want, tc.fail)
		}
	}
}
