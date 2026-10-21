package main

import (
	"encoding/json"
	"fmt"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/engine"
	"github.com/spf13/cobra"
)

func sttRuntimeCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "runtime", Short: "Gestionar el motor de dictado"}
	status := &cobra.Command{
		Use: "status", Short: "Mostrar el estado del motor", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			installed := engine.RuntimeInstalled()
			provider := engine.RuntimeProvider()
			path := stt.RuntimeDir()
			asJSON, _ := cmd.Flags().GetBool("json")
			if asJSON {
				return json.NewEncoder(cmd.OutOrStdout()).Encode(struct {
					Installed bool   `json:"installed"`
					Provider  string `json:"provider"`
					Path      string `json:"path"`
				}{installed, provider, path})
			}
			if !installed {
				_, err := fmt.Fprintln(cmd.OutOrStdout(), "Motor de dictado no instalado")
				return err
			}
			_, err := fmt.Fprintf(cmd.OutOrStdout(), "Motor instalado: %s (%s)\n", provider, path)
			return err
		},
	}
	status.Flags().Bool("json", false, "Mostrar como JSON")
	install := &cobra.Command{
		Use: "install", Short: "Instalar el motor de dictado", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cmd.SilenceUsage = true
			if err := engine.InstallRuntime(cmd.Context(), cmd.OutOrStdout()); err != nil {
				return err
			}
			_, err := fmt.Fprintf(cmd.OutOrStdout(), "Motor instalado: %s\n", engine.RuntimeProvider())
			return err
		},
	}
	cmd.AddCommand(status, install)
	return cmd
}
