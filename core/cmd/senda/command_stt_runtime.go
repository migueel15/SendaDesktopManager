package main

import "github.com/spf13/cobra"

func sttRuntimeCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "runtime", Short: "Gestionar el motor de dictado"}
	status := sttStubCmd("status", "Mostrar el estado del motor", cobra.NoArgs)
	status.Flags().Bool("json", false, "Mostrar como JSON")
	cmd.AddCommand(status, sttStubCmd("install", "Instalar el motor de dictado", cobra.NoArgs))
	return cmd
}
