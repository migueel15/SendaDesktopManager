package main

import "github.com/spf13/cobra"

func sttShortcutCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "shortcut", Short: "Gestionar el atajo de dictado"}
	show := sttStubCmd("show", "Mostrar el atajo de dictado", cobra.NoArgs)
	show.Flags().Bool("json", false, "Mostrar como JSON")
	cmd.AddCommand(show,
		sttStubCmd("set <combo>", "Configurar el atajo de dictado", cobra.ExactArgs(1)),
		sttStubCmd("apply", "Aplicar el atajo en Hyprland", cobra.NoArgs),
	)
	return cmd
}
