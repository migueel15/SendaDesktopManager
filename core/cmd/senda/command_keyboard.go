package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"os"

	"github.com/migueel15/SendaDesktopManager/core/internal/keyboard"
	"github.com/spf13/cobra"
)

func keyboardCmd() *cobra.Command {
	root := &cobra.Command{Use: "keyboard", Short: "Control physical keyboards"}
	for _, action := range []string{"toggle", "on", "off", "status", "devices"} {
		action := action
		root.AddCommand(&cobra.Command{Use: action, Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
			controller := keyboard.DefaultController(func() (bool, error) {
				result, err := callShellIPCResult(cmd, "lock", "isLocked")
				if err != nil {
					return false, err
				}
				switch result {
				case "true":
					return true, nil
				case "false":
					return false, nil
				default:
					return false, fmt.Errorf("estado de bloqueo inválido: %q", result)
				}
			})
			var value any
			var err error
			switch action {
			case "devices":
				value, err = controller.Detect()
			case "status":
				value, err = controller.Status()
			default:
				value, err = controller.Set(action)
			}
			if value != nil {
				data, e := json.MarshalIndent(value, "", "  ")
				if e != nil {
					return e
				}
				fmt.Fprintln(cmd.OutOrStdout(), string(data))
			}
			return err
		}})
	}
	root.AddCommand(&cobra.Command{Use: "watch", Hidden: true, Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		exitWithParent()
		watchKeyboardReload(cmd.Context())
		return nil
	}})
	return root
}

func lockCmd() *cobra.Command {
	return &cobra.Command{Use: "lock", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error { _, err := callShellIPC(cmd, "lock", "lock"); return err }}
}

// watchKeyboardReload tracks compositor reloads while the shell is alive.
func watchKeyboardReload(ctx context.Context) {
	hyprctl.WatchEvents(ctx, func(name, _ string) {
		if name != hyprctl.EventConfigReloaded {
			return
		}
		if _, err := keyboard.DefaultController(nil).Reset(); err != nil {
			fmt.Fprintln(os.Stderr, "keyboard reload:", err)
		}
	})
}
