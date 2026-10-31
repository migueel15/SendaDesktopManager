package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt/postprocess"
	"github.com/spf13/cobra"
)

func sttPostprocessCmd() *cobra.Command { return newSTTPostprocessCmd(postprocess.ManagedStore) }

func newSTTPostprocessCmd(store func() *postprocess.Store) *cobra.Command {
	cmd := &cobra.Command{Use: "postprocess", Short: "Preparar la corrección local del dictado"}
	status := &cobra.Command{Use: "status", Args: cobra.NoArgs, Short: "Consultar si la corrección está preparada", RunE: func(cmd *cobra.Command, _ []string) error {
		s := store().Status(cmd.Context())
		asJSON, _ := cmd.Flags().GetBool("json")
		if asJSON {
			return json.NewEncoder(cmd.OutOrStdout()).Encode(s)
		}
		_, err := fmt.Fprintln(cmd.OutOrStdout(), s.Message)
		return err
	}}
	status.Flags().Bool("json", false, "Mostrar como JSON")
	install := &cobra.Command{Use: "install", Args: cobra.NoArgs, Short: "Descargar y preparar el motor y el modelo locales", RunE: func(cmd *cobra.Command, _ []string) error {
		cmd.SilenceUsage = true
		ctx, cancel := signal.NotifyContext(cmd.Context(), os.Interrupt, syscall.SIGTERM)
		defer cancel()
		enc := json.NewEncoder(cmd.OutOrStdout())
		if err := store().Install(ctx, func(phase string, done, total int64) {
			_ = enc.Encode(map[string]any{"event": "progress", "phase": phase, "done": done, "total": total})
		}); err != nil {
			return err
		}
		return enc.Encode(map[string]string{"event": "done"})
	}}
	cmd.AddCommand(status, install)
	return cmd
}
