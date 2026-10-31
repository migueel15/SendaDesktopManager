package main

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/control"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/engine"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/models"
	"github.com/spf13/cobra"
)

type sttShell struct{ cmd *cobra.Command }

func (s sttShell) Call(ctx context.Context, function string) (string, error) {
	result, err := callShellIPC(s.cmd, "stt", function)
	if err != nil {
		return "", err
	}
	if response := strings.TrimSpace(result); response == "Target not found." || response == "Function not found." {
		return "", errors.New("El control de dictado no está disponible en la shell de Senda. Reinicia la shell y vuelve a intentarlo.")
	}
	return result, nil
}

func sttPreflight(cmd *cobra.Command) error {
	values, err := config.Load(paths.ConfigFile())
	if err != nil {
		return fmt.Errorf("No se pudo leer la configuración del dictado: %w", err)
	}
	checks := control.Checks{
		ModelInstalled:   models.NewStore(stt.ModelsDir()).Installed,
		RuntimeInstalled: engine.RuntimeInstalled,
		Microphone:       func(ctx context.Context) error { return control.CheckMicrophone(ctx, stt.ExecRunner) },
	}
	return control.Preflight(cmd.Context(), stt.LoadSettings(values), checks)
}

func newSTTToggleCmd(shellFor func(*cobra.Command) control.Shell, preflight func(*cobra.Command) error, notifier stt.Notifier) *cobra.Command {
	return &cobra.Command{Use: "toggle", Short: "Iniciar o detener el dictado", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cmd.SilenceUsage = true
			var preflightErr error
			_, err := control.Toggle(cmd.Context(), shellFor(cmd), func() error {
				preflightErr = preflight(cmd)
				return preflightErr
			})
			if preflightErr != nil {
				_ = notifier.Notify(cmd.Context(), "Dictado no disponible", preflightErr.Error())
			}
			return err
		}}
}

func newSTTCancelCmd(shellFor func(*cobra.Command) control.Shell, submapFor func(*cobra.Command) stt.Submap) *cobra.Command {
	return &cobra.Command{Use: "cancel", Short: "Cancelar el dictado", Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cmd.SilenceUsage = true
			return control.CancelAndReset(cmd.Context(), shellFor(cmd), submapFor(cmd))
		}}
}

func sttCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "stt", Short: "Dictado por voz"}
	cmd.AddCommand(
		newSTTToggleCmd(func(cmd *cobra.Command) control.Shell { return sttShell{cmd} }, sttPreflight, control.NewNotifier()),
		newSTTCancelCmd(func(cmd *cobra.Command) control.Shell { return sttShell{cmd} }, func(*cobra.Command) stt.Submap { return binds.NewSubmap(stt.ExecRunner) }),
		&cobra.Command{Use: "status", Short: "Mostrar el estado del dictado", Args: cobra.NoArgs,
			RunE: func(cmd *cobra.Command, _ []string) error {
				cmd.SilenceUsage = true
				status, err := control.Status(cmd.Context(), sttShell{cmd})
				if err != nil {
					return err
				}
				_, err = fmt.Fprintln(cmd.OutOrStdout(), strings.TrimSpace(status))
				return err
			}},
		sttSessionCmd(), sttModelsCmd(), sttShortcutCmd(), sttRuntimeCmd(), sttPostprocessCmd(),
	)
	return cmd
}
