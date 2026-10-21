package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/spf13/cobra"
)

func TestUninstallDisablesBindsBeforeStoppingShell(t *testing.T) {
	path := filepath.Join(t.TempDir(), "senda_binds.lua")
	if err := os.WriteFile(path, []byte("hl.bind('x')\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	var order []string
	var removed []string
	out, warnings := &strings.Builder{}, &strings.Builder{}
	cmd := &cobra.Command{}
	cmd.SetOut(out)
	cmd.SetErr(warnings)
	deps := uninstallDeps{
		getenv:        func(string) string { return "" },
		executable:    func() (string, error) { return "/tmp/fake-senda", nil },
		cancelSession: func(context.Context) error { order = append(order, "cancel"); return errors.New("no IPC") },
		removeService: func() error { order = append(order, "service"); return nil },
		closeShell:    func() bool { order = append(order, "shell"); return true },
		stopBridge:    func() error { return nil },
		bindsPath:     func() string { return path }, stat: os.Stat,
		writeBinds: func(p string, data []byte) error {
			order = append(order, "write")
			return os.WriteFile(p, data, 0o600)
		},
		reloadBinds: func(context.Context) error { order = append(order, "reload"); return nil },
		removeAll:   func(p string) error { removed = append(removed, p); return nil },
	}
	if err := runUninstallWith(cmd, true, deps); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(order, ","); got != "cancel,write,reload,service,shell" {
		t.Fatalf("operation order = %s", got)
	}
	data, err := os.ReadFile(path)
	if err != nil || strings.Contains(string(data), "hl.bind") {
		t.Fatalf("binds not disabled: %q, %v", data, err)
	}
	for _, target := range removed {
		if target == path {
			t.Fatal("binds module was removed")
		}
	}
	if !strings.Contains(out.String(), `require("modules.senda_binds")`) || !strings.Contains(warnings.String(), "no IPC") {
		t.Fatalf("missing guidance or warning: out=%q warnings=%q", out, warnings)
	}
}
