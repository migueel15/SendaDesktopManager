package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/integration"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/spf13/cobra"
)

// inputStatus is what `senda input show` reports. Current holds the value in
// effect; User only has the fields defined by the user's configuration.
type inputStatus struct {
	Current map[string]string                  `json:"current"`
	User    map[string]integration.UserSetting `json:"user"`
	Themes  []string                           `json:"cursorThemes"`
}

var inputOptions = map[string]string{
	integration.FieldLayout:        "input:kb_layout",
	integration.FieldSensitivity:   "input:sensitivity",
	integration.FieldTapToClick:    "input:touchpad:tap-to-click",
	integration.FieldNaturalScroll: "input:touchpad:natural_scroll",
}

func readInputStatus(ctx context.Context, s integration.InputSettings) inputStatus {
	user := integration.DetectInput(integration.LoadUserConfig(), integration.SessionEnvFiles())
	senda := map[string]string{integration.FieldLayout: s.Layout, integration.FieldSensitivity: s.Sensitivity, integration.FieldTapToClick: s.TapToClick, integration.FieldNaturalScroll: s.NaturalScroll, integration.FieldCursorTheme: s.CursorTheme}
	current := map[string]string{}
	for field, value := range senda {
		if u, ok := user[field]; ok {
			value = u.Value
		}
		option := inputOptions[field]
		if option != "" && integration.InSession() {
			if live, err := hyprctl.New(shortcutRunner).Option(ctx, option); err == nil {
				if field == integration.FieldTapToClick || field == integration.FieldNaturalScroll {
					live = strconv.FormatBool(live == "1")
				}
				value = live
			}
		}
		if field == integration.FieldCursorTheme && value == "" {
			value = os.Getenv("XCURSOR_THEME")
		}
		current[field] = value
	}
	return inputStatus{Current: current, User: user, Themes: integration.CursorThemes()}
}

func printInput(cmd *cobra.Command, status inputStatus, asJSON bool) error {
	if asJSON {
		return writeJSON(cmd, status)
	}
	labels := []struct{ field, label string }{{integration.FieldLayout, "Distribución"}, {integration.FieldSensitivity, "Velocidad del ratón"}, {integration.FieldTapToClick, "Tocar para hacer clic"}, {integration.FieldNaturalScroll, "Desplazamiento natural"}, {integration.FieldCursorTheme, "Tema de cursor"}}
	for _, l := range labels {
		line := fmt.Sprintf("%s: %s", l.label, status.Current[l.field])
		if u, ok := status.User[l.field]; ok {
			line += " (gestionado por el usuario en " + u.File + ")"
		}
		fmt.Fprintln(cmd.OutOrStdout(), line)
	}
	return nil
}

// applyInput rewrites the module, which leaves out what the user defines, and
// applies the cursor at once because a reload does not change it.
func applyInput(ctx context.Context, s integration.Settings, cursorChanged bool) error {
	if _, err := applyHyprland(ctx, s, false); err != nil {
		return err
	}
	user := integration.DetectInput(integration.LoadUserConfig(), integration.SessionEnvFiles())
	if _, managed := user[integration.FieldCursorTheme]; cursorChanged && !managed && s.Input.CursorTheme != "" && integration.InSession() {
		return hyprctl.New(shortcutRunner).SetCursor(ctx, s.Input.CursorTheme, integration.CursorSize())
	}
	return nil
}

func inputCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "input", Short: "Teclado, ratón, touchpad y cursor", SilenceUsage: true}
	var asJSON bool
	show := &cobra.Command{Use: "show", Short: "Mostrar ajustes y lo que gestiona el usuario", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		s, err := integration.ReadSettings()
		if err != nil {
			return fmt.Errorf("leer ajustes: %w", err)
		}
		return printInput(cmd, readInputStatus(cmd.Context(), s.Input), asJSON)
	}}
	themes := &cobra.Command{Use: "cursor-themes", Short: "Listar los temas de cursor instalados", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		if asJSON {
			return writeJSON(cmd, integration.CursorThemes())
		}
		fmt.Fprintln(cmd.OutOrStdout(), strings.Join(integration.CursorThemes(), "\n"))
		return nil
	}}
	sync := &cobra.Command{Use: "sync", Short: "Regenerar el módulo si cambió la configuración del usuario", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		s, err := integration.ReadSettings()
		if err != nil {
			return fmt.Errorf("leer ajustes: %w", err)
		}
		if integration.InSession() {
			if link, err := integration.Probe(cmd.Context(), shortcutRunner); err == nil {
				integration.Locate(link)
			}
		}
		changed, err := integration.SyncInputModule(s)
		if err != nil {
			return err
		}
		if changed && integration.InSession() {
			if err := hyprctl.New(shortcutRunner).Reload(cmd.Context()); err != nil {
				return err
			}
		}
		return printInput(cmd, readInputStatus(cmd.Context(), s.Input), asJSON)
	}}
	var layout, sensitivity, tap, natural, cursor string
	set := &cobra.Command{Use: "set", Short: "Cambiar ajustes (valor vacío: Senda deja de definirlo)", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		s, err := integration.ReadSettings()
		if err != nil {
			return fmt.Errorf("leer ajustes: %w", err)
		}
		user := integration.DetectInput(integration.LoadUserConfig(), integration.SessionEnvFiles())
		changes := []struct {
			flag, field string
			value       string
			target      *string
		}{{"layout", integration.FieldLayout, layout, &s.Input.Layout}, {"sensitivity", integration.FieldSensitivity, sensitivity, &s.Input.Sensitivity}, {"tap-to-click", integration.FieldTapToClick, tap, &s.Input.TapToClick}, {"natural-scroll", integration.FieldNaturalScroll, natural, &s.Input.NaturalScroll}, {"cursor-theme", integration.FieldCursorTheme, cursor, &s.Input.CursorTheme}}
		for _, c := range changes {
			if !cmd.Flags().Changed(c.flag) {
				continue
			}
			if u, ok := user[c.field]; ok {
				return fmt.Errorf("%s lo gestiona tu configuración (%s); cámbialo allí", c.flag, u.File)
			}
			*c.target = c.value
		}
		cursorChanged := cmd.Flags().Changed("cursor-theme")
		if cursorChanged && cursor != "" {
			found := false
			for _, theme := range integration.CursorThemes() {
				found = found || theme == cursor
			}
			if !found {
				return fmt.Errorf("el tema de cursor %q no está instalado", cursor)
			}
		}
		if err := integration.SaveInputSettings(paths.ConfigFile(), s.Input); err != nil {
			return err
		}
		if err := applyInput(cmd.Context(), s, cursorChanged); err != nil {
			return err
		}
		return printInput(cmd, readInputStatus(cmd.Context(), s.Input), asJSON)
	}}
	set.Flags().StringVar(&layout, "layout", "", "Distribución, p. ej. es o us,es")
	set.Flags().StringVar(&sensitivity, "sensitivity", "", "Velocidad del ratón, de -1 a 1")
	set.Flags().StringVar(&tap, "tap-to-click", "", "true o false")
	set.Flags().StringVar(&natural, "natural-scroll", "", "true o false")
	set.Flags().StringVar(&cursor, "cursor-theme", "", "Tema de cursor instalado")
	cmd.PersistentFlags().BoolVar(&asJSON, "json", false, "Mostrar JSON")
	cmd.AddCommand(show, set, themes, sync)
	return cmd
}
