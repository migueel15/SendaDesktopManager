package main

import "github.com/spf13/cobra"

func sttSessionCmd() *cobra.Command {
	return sttStubCmd("session", "Ejecutar una sesión con órdenes por stdin y eventos JSON por stdout", cobra.NoArgs)
}
