package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/control"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/deliver"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/engine"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/models"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/session"
	"github.com/spf13/cobra"
)

func sttSessionCmd() *cobra.Command {
	return newSTTSessionCmd(func() (session.Deps, error) {
		values, err := config.Load(paths.ConfigFile())
		if err != nil {
			return session.Deps{}, fmt.Errorf("no se pudo leer la configuración del dictado: %w", err)
		}
		settings := stt.LoadSettings(values)
		return session.Deps{
			Engine: engine.New(), Deliverer: deliver.New(stt.ExecRunner),
			Submap: binds.NewSubmap(stt.ExecRunner), Notifier: control.NewNotifier(),
			Settings: settings, ModelDir: models.NewStore(stt.ModelsDir()).ModelDir(settings.ModelID),
		}, nil
	})
}

func newSTTSessionCmd(load func() (session.Deps, error)) *cobra.Command {
	var standby bool
	cmd := &cobra.Command{
		Use: "session", Short: "Ejecutar una sesión con órdenes por stdin y eventos JSON por stdout", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cmd.SilenceUsage = true
			ctx, stop := signal.NotifyContext(cmd.Context(), os.Interrupt, syscall.SIGTERM)
			defer stop()
			deps, err := load()
			if err != nil {
				return err
			}
			deps.Standby = standby
			return session.Run(ctx, deps, cmd.InOrStdin(), cmd.OutOrStdout())
		},
	}
	cmd.Flags().BoolVar(&standby, "standby", false, "Precargar el motor sin abrir el micrófono")
	return cmd
}
