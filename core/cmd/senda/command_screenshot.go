package main

import (
	"fmt"
	"image"
	"os"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/screenshot"
	"github.com/spf13/cobra"
)

func screenshotCmd() *cobra.Command {
	cmd := &cobra.Command{Use: "screenshot", Short: "Seleccionar una captura de pantalla", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		result, err := callShellIPCResult(cmd, "screenshot", "capture")
		if err != nil {
			return err
		}
		if result != "true" {
			return fmt.Errorf("ya hay una captura o un editor en curso")
		}
		return nil
	}}
	freeze := &cobra.Command{Use: "freeze <salida>...", Hidden: true, Args: cobra.MinimumNArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		files, err := screenshot.Freeze(cmd.Context(), args)
		if err != nil {
			return err
		}
		return writeJSON(cmd, files)
	}}
	cleanup := &cobra.Command{Use: "cleanup <sesión>", Hidden: true, Args: cobra.ExactArgs(1), RunE: func(_ *cobra.Command, args []string) error { return screenshot.Cleanup(args[0]) }}
	info := &cobra.Command{Use: "info <png>", Hidden: true, Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		img, err := screenshot.Read(args[0])
		if err != nil {
			return err
		}
		return writeJSON(cmd, map[string]int{"width": img.Bounds().Dx(), "height": img.Bounds().Dy()})
	}}
	var in, out string
	var x, y, w, h int
	var copyImage, save bool
	var cache bool
	crop := &cobra.Command{Use: "crop", Hidden: true, Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		img, err := screenshot.Read(in)
		if err != nil {
			return err
		}
		if x < 0 || y < 0 || w <= 0 || h <= 0 || x > img.Bounds().Dx() || y > img.Bounds().Dy() || w > img.Bounds().Dx()-x || h > img.Bounds().Dy()-y {
			return fmt.Errorf("el recorte está fuera de la imagen o vacío")
		}
		img, err = screenshot.Crop(img, image.Rect(x, y, x+w, y+h))
		if err != nil {
			return err
		}
		if out != "" {
			err = screenshot.Write(out, img)
		} else if cache {
			out, err = screenshot.Cache(img)
		}
		if err != nil {
			return err
		}
		result := out
		if save {
			values, e := config.Load(paths.ConfigFile())
			if e != nil {
				return e
			}
			configured := os.Getenv(screenshot.KeyDirectory)
			if configured == "" {
				configured = values[screenshot.KeyDirectory]
			}
			dir, e := screenshot.DefaultDirectory(cmd.Context(), configured)
			if e != nil {
				return e
			}
			result, err = screenshot.Save(img, dir, time.Now())
			if err != nil {
				return err
			}
		}
		if copyImage {
			if err = screenshot.Copy(cmd.Context(), img); err != nil {
				return err
			}
		}
		return writeJSON(cmd, map[string]string{"path": result, "image": out})
	}}
	crop.Flags().StringVar(&in, "in", "", "PNG de entrada")
	crop.Flags().StringVar(&out, "out", "", "PNG de salida (caché si se omite)")
	crop.Flags().IntVar(&x, "x", 0, "X en píxeles")
	crop.Flags().IntVar(&y, "y", 0, "Y en píxeles")
	crop.Flags().IntVar(&w, "w", 0, "Ancho en píxeles")
	crop.Flags().IntVar(&h, "h", 0, "Alto en píxeles")
	crop.Flags().BoolVar(&cache, "cache", true, "Conservar el recorte en caché")
	crop.Flags().BoolVar(&copyImage, "copy", false, "Copiar al portapapeles")
	crop.Flags().BoolVar(&save, "save", false, "Guardar en la carpeta configurada")
	cmd.AddCommand(freeze, cleanup, info, crop)
	return cmd
}
