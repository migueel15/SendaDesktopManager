package main

import (
	"encoding/json"
	"fmt"
	"text/tabwriter"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/models"
	"github.com/spf13/cobra"
)

type modelListItem struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	Languages  []string `json:"languages"`
	SizeBytes  int64    `json:"sizeBytes"`
	License    string   `json:"license"`
	LicenseURL string   `json:"licenseUrl"`
	Installed  bool     `json:"installed"`
	Active     bool     `json:"active"`
}

func sttModelsCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "models", Short: "Gestionar los modelos de dictado"}
	list := &cobra.Command{Use: "list", Short: "Listar los modelos disponibles", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		cmd.SilenceUsage = true
		store := models.NewStore(stt.ModelsDir())
		statuses, err := store.List(stt.LoadSettings(map[string]string{stt.KeyModel: paths.Setting(stt.KeyModel)}).ModelID)
		if err != nil {
			return err
		}
		asJSON, _ := cmd.Flags().GetBool("json")
		if asJSON {
			items := make([]modelListItem, 0, len(statuses))
			for _, s := range statuses {
				items = append(items, modelListItem{ID: s.ID, Name: s.Name, Languages: s.Languages, SizeBytes: s.SizeBytes, License: s.License, LicenseURL: s.LicenseURL, Installed: s.Installed, Active: s.Active})
			}
			return json.NewEncoder(cmd.OutOrStdout()).Encode(items)
		}
		w := tabwriter.NewWriter(cmd.OutOrStdout(), 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "ID\tNOMBRE\tIDIOMAS\tTAMAÑO (B)\tLICENCIA\tINSTALADO\tACTIVO")
		for _, s := range statuses {
			fmt.Fprintf(w, "%s\t%s\t%v\t%d\t%s\t%t\t%t\n", s.ID, s.Name, s.Languages, s.SizeBytes, s.License, s.Installed, s.Active)
		}
		return w.Flush()
	}}
	list.Flags().Bool("json", false, "Mostrar como JSON")
	install := &cobra.Command{Use: "install <id>", Short: "Instalar un modelo", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		cmd.SilenceUsage = true
		store := models.NewStore(stt.ModelsDir())
		enc := json.NewEncoder(cmd.OutOrStdout())
		err := store.Install(cmd.Context(), args[0], func(done, total int64) {
			_ = enc.Encode(map[string]any{"event": "progress", "done": done, "total": total})
		})
		if err != nil {
			return err
		}
		return enc.Encode(map[string]string{"event": "done"})
	}}
	remove := &cobra.Command{Use: "remove <id>", Short: "Eliminar un modelo", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		cmd.SilenceUsage = true
		store := models.NewStore(stt.ModelsDir())
		if err := store.Remove(args[0]); err != nil {
			return err
		}
		if stt.LoadSettings(map[string]string{stt.KeyModel: paths.Setting(stt.KeyModel)}).ModelID == args[0] {
			if err := config.Set(paths.ConfigFile(), map[string]string{stt.KeyModel: ""}); err != nil {
				return err
			}
		}
		return nil
	}}
	use := &cobra.Command{Use: "use <id>", Short: "Seleccionar el modelo activo", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		cmd.SilenceUsage = true
		store := models.NewStore(stt.ModelsDir())
		if !store.Installed(args[0]) {
			return fmt.Errorf("modelo %q no está instalado", args[0])
		}
		return config.Set(paths.ConfigFile(), map[string]string{stt.KeyModel: args[0]})
	}}
	cmd.AddCommand(list, install, remove, use)
	return cmd
}
