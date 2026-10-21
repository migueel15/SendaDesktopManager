package main

import "github.com/spf13/cobra"

func sttModelsCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "models", Short: "Gestionar los modelos de dictado"}
	list := sttStubCmd("list", "Listar los modelos disponibles", cobra.NoArgs)
	list.Flags().Bool("json", false, "Mostrar como JSON")
	cmd.AddCommand(list,
		sttStubCmd("install <id>", "Instalar un modelo", cobra.ExactArgs(1)),
		sttStubCmd("remove <id>", "Eliminar un modelo", cobra.ExactArgs(1)),
		sttStubCmd("use <id>", "Seleccionar el modelo activo", cobra.ExactArgs(1)),
	)
	return cmd
}
