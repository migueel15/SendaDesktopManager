package awww

import (
	"fmt"
	"os/exec"
	"strconv"

	"github.com/migueel15/SendaDesktopManager/core/internal/wallpaper"
)

type Backend struct{}

var _ wallpaper.Backend = (*Backend)(nil)

func NewBackend() *Backend {
	return &Backend{}
}

func (backend *Backend) Set(w wallpaper.Wallpaper, options wallpaper.SetOptions) error {
	var positionStr string

	if options.Animation.Origin != nil {
		positionStr = fmt.Sprintf("%d,%d", options.Animation.Origin.X, options.Animation.Origin.Y)
	} else {
		positionStr = "center"
	}
	println(string(options.Animation.Kind))

	cmd := exec.Command(
		"awww",
		"img",
		"--transition-bezier", ".61,.18,.48,.9",
		"--transition-duration", "1",
		"--transition-fps", strconv.Itoa(options.Animation.FPS),
		"--transition-type", string(options.Animation.Kind),
		"--transition-pos", positionStr, w.Path)

	cmd.Run()
	return nil
}
