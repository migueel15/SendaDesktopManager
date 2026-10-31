package main

import (
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/clipboard"
	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

func clipboardStore() clipboard.Store {
	return clipboard.Store{Path: filepath.Join(paths.StateDir(), "clipboard-history.json")}
}

func clipboardCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "clipboard", Short: "Consultar el historial del portapapeles"}
	var asJSON bool
	list := &cobra.Command{
		Use: "list", Short: "Listar el historial, primero lo más reciente", Args: cobra.NoArgs, SilenceUsage: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			entries, err := clipboardStore().List()
			if err != nil {
				return err
			}
			if asJSON {
				return writeJSON(cmd, entries)
			}
			for _, entry := range entries {
				fmt.Fprintf(cmd.OutOrStdout(), "%s\t%s\n", entry.ID, strings.Join(strings.Fields(entry.Text), " "))
			}
			return nil
		},
	}
	list.Flags().BoolVar(&asJSON, "json", false, "Salida en JSON")
	cmd.AddCommand(list, &cobra.Command{
		Use: "restore <id>", Short: "Devolver una entrada al portapapeles", Args: cobra.ExactArgs(1), SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			entry, err := clipboardStore().Find(args[0])
			if err != nil {
				return err
			}
			return clipboard.Restore(cmd.Context(), entry.Text)
		},
	}, &cobra.Command{
		Use: "clear", Short: "Vaciar el historial", Args: cobra.NoArgs, SilenceUsage: true,
		RunE: func(*cobra.Command, []string) error { return clipboardStore().Clear() },
	}, &cobra.Command{
		Use: "store", Short: "Guardar la copia que entrega wl-paste", Hidden: true, Args: cobra.NoArgs, SilenceUsage: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			values, err := config.Load(paths.ConfigFile())
			if err != nil {
				return err
			}
			return clipboard.Capture(clipboardStore(), os.Getenv("CLIPBOARD_STATE"), cmd.InOrStdin(), clipboard.LoadSettings(values), time.Now())
		},
	}, &cobra.Command{
		Use: "watch", Short: "Registrar lo que se copia", Hidden: true, Args: cobra.NoArgs, SilenceUsage: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			exitWithParent()
			executable, err := os.Executable()
			if err != nil {
				return err
			}
			ctx, stop := signal.NotifyContext(cmd.Context(), os.Interrupt, syscall.SIGTERM)
			defer stop()
			return clipboard.Watch(ctx, executable, "clipboard", "store")
		},
	})
	return cmd
}
