package main

import (
	"os"
	"os/signal"
	"syscall"

	"github.com/migueel15/SendaDesktopManager/core/internal/usb"
	"github.com/spf13/cobra"
)

func usbCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "usb", Short: "Gestionar dispositivos USB"}
	cmd.AddCommand(&cobra.Command{
		Use: "watch", Short: "Montar los dispositivos USB al conectarlos", Hidden: true, Args: cobra.NoArgs, SilenceUsage: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			ctx, stop := signal.NotifyContext(cmd.Context(), os.Interrupt, syscall.SIGTERM)
			defer stop()
			return usb.Watch(ctx)
		},
	})
	return cmd
}
