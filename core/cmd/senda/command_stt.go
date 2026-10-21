package main

import (
	"fmt"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/spf13/cobra"
)

func sttCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "stt", Short: "Dictado por voz"}
	cmd.AddCommand(
		sttStubCmd("toggle", "Iniciar o detener el dictado", cobra.NoArgs),
		sttStubCmd("cancel", "Cancelar el dictado", cobra.NoArgs),
		sttStubCmd("status", "Mostrar el estado del dictado", cobra.NoArgs),
		sttSessionCmd(), sttModelsCmd(), sttShortcutCmd(), sttRuntimeCmd(),
	)
	return cmd
}

// sttStubCmd reserves the command contract for the implementing task.
func sttStubCmd(use, short string, args cobra.PositionalArgs) *cobra.Command {
	return &cobra.Command{
		Use: use, Short: short, Args: args,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cmd.SilenceUsage = true
			return fmt.Errorf("%s todavía no está implementado: %w", cmd.CommandPath(), stt.ErrNotImplemented)
		},
	}
}
