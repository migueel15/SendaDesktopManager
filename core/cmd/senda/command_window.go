package main

import (
	"github.com/migueel15/SendaDesktopManager/core/internal/windowfocus"
	"github.com/spf13/cobra"
)

func windowCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "window",
		Short: "Manage desktop windows",
	}
	cmd.AddCommand(windowFocusCmd())
	return cmd
}

func windowFocusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "focus <class>",
		Short: "Focus the first window with an exact class match",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			backend, err := windowfocus.DetectBackend()
			if err != nil {
				cmd.SilenceUsage = true
				return err
			}
			if err := windowfocus.FocusClass(cmd.Context(), backend, args[0]); err != nil {
				cmd.SilenceUsage = true
				return err
			}
			return nil
		},
	}
}
