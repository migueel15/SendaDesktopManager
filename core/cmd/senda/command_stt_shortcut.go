package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/spf13/cobra"
)

type shortcutStatus struct {
	Shortcut    string   `json:"shortcut"`
	Path        string   `json:"path"`
	Exists      bool     `json:"exists"`
	Loaded      bool     `json:"loaded"`
	RequireLine string   `json:"requireLine"`
	Conflicts   []string `json:"conflicts"`
}

func sttShortcutCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "shortcut", Short: "Gestionar el atajo de dictado"}
	show := &cobra.Command{
		Use: "show", Short: "Mostrar el atajo de dictado", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			status, err := currentShortcutStatus(cmd.Context())
			if err != nil {
				return err
			}
			asJSON, _ := cmd.Flags().GetBool("json")
			return printShortcutStatus(cmd, status, asJSON)
		},
	}
	show.Flags().Bool("json", false, "Mostrar como JSON")
	set := &cobra.Command{
		Use: "set <combo>", Short: "Configurar el atajo de dictado", Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := integration.ReadSettings()
			if err != nil {
				return err
			}
			s.DictationShortcut, err = binds.NormalizeShortcut(args[0])
			if err != nil {
				return fmt.Errorf("atajo de dictado: %w", err)
			}
			if _, err = applyHyprland(cmd.Context(), s); err != nil {
				return err
			}

			status, err := currentShortcutStatus(cmd.Context())
			if err != nil {
				return err
			}
			asJSON, _ := cmd.Flags().GetBool("json")
			return printShortcutStatus(cmd, status, asJSON)
		},
	}
	set.Flags().Bool("json", false, "Mostrar como JSON")
	apply := &cobra.Command{
		Use: "apply", Short: "Aplicar el atajo en Hyprland", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			s, err := integration.ReadSettings()
			if err != nil {
				return err
			}
			if _, err = applyHyprland(cmd.Context(), s); err != nil {
				return err
			}
			shortcut := s.DictationShortcut

			fmt.Fprintln(cmd.OutOrStdout(), "Atajo aplicado:", shortcut)
			return nil
		},
	}
	cmd.AddCommand(show, set, apply)
	return cmd
}

func configuredShortcut() (string, error) {
	s, err := integration.ReadSettings()
	if err != nil {
		return "", err
	}
	return binds.NormalizeShortcut(s.DictationShortcut)
}

func currentShortcutStatus(ctx context.Context) (shortcutStatus, error) {
	s, err := integration.ReadSettings()
	if err != nil {
		return shortcutStatus{}, err
	}
	state := integration.Inspect(ctx, s, shortcutRunner)
	status := shortcutStatus{Shortcut: s.DictationShortcut, Path: state.ModulePath, Loaded: state.ModuleActive, RequireLine: integration.RequireLine, Conflicts: []string{}}
	if _, err = os.Stat(status.Path); err == nil {
		status.Exists = true
	} else if !os.IsNotExist(err) {
		return status, err
	}
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "" {
		conflicts, err := binds.Conflicts(ctx, shortcutRunner, s.DictationShortcut)
		if err != nil {
			return status, err
		}
		status.Conflicts = conflicts
	}
	return status, nil
}

func printShortcutStatus(cmd *cobra.Command, status shortcutStatus, asJSON bool) error {
	if asJSON {
		return writeJSON(cmd, status)
	}
	fmt.Fprintf(cmd.OutOrStdout(), "Atajo: %s\nMódulo: %s\nExiste: %t\nCargado: %t\nAñade a hyprland.lua: %s\n", status.Shortcut, status.Path, status.Exists, status.Loaded, status.RequireLine)
	for _, conflict := range status.Conflicts {
		fmt.Fprintln(cmd.OutOrStdout(), "Conflicto:", conflict)
	}
	return nil
}

// CombinedOutput preserves Hyprland diagnostics on nonzero exits; ExecRunner
// only returns stdout, which would hide the reason a reload failed.
func shortcutRunner(ctx context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
	command := exec.CommandContext(ctx, name, args...)
	out, err := command.CombinedOutput()
	if err != nil {
		return out, fmt.Errorf("%s %s: %w", name, strings.Join(args, " "), err)
	}
	return out, nil
}
