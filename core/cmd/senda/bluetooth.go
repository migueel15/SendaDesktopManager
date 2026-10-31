package main

import (
	"github.com/migueel15/SendaDesktopManager/core/internal/bluetooth"
	"github.com/spf13/cobra"
)

func bluetoothCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "bluetooth", Short: "Gestionar Bluetooth"}
	cmd.AddCommand(&cobra.Command{
		Use: "pair <device-path>", Short: "Emparejar con confirmaciones JSON por entrada y salida estándar", Args: cobra.ExactArgs(1), SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return bluetooth.Pair(cmd.Context(), args[0], cmd.InOrStdin(), cmd.OutOrStdout())
		},
	})
	return cmd
}
