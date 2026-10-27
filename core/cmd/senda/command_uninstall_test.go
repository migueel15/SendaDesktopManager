package main

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/spf13/cobra"
)

func TestUninstallDisablesBindsBeforeStoppingShell(t *testing.T) {
	var order []string
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
		removeIntegration: func() ([]string, error) {
			order = append(order, "integration")
			return []string{"referencia manual"}, nil
		},
		removeAll: func(string) error { return nil },
	}
	if err := runUninstallWith(cmd, true, deps); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(order, ","); got != "cancel,integration,service,shell" {
		t.Fatalf("operation order = %s", got)
	}

	if !strings.Contains(warnings.String(), "no IPC") {
		t.Fatalf("missing guidance or warning: out=%q warnings=%q", out, warnings)
	}
}
