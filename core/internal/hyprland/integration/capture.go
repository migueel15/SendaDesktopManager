package integration

import (
	"context"
	"fmt"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// StartCapture enters the empty capture submap so that Hyprland does not
// consume the shortcut being recorded.
func StartCapture(ctx context.Context, run stt.Runner) error {
	if !InSession() {
		return fmt.Errorf("no hay una sesión de Hyprland")
	}
	// Define the submap on the fly, so recording does not depend on the
	// version of the loaded module. Redefining it is harmless.
	if err := hyprctl.New(run).Eval(ctx, captureSubmapLua); err != nil {
		return fmt.Errorf("definir el modo de grabación: %w", err)
	}
	return dispatchSubmap(ctx, run, CaptureSubmap)
}

// captureSubmapLua defines the capture submap: only Escape, which leaves it.
var captureSubmapLua = hyprctl.DefineSubmap(CaptureSubmap,
	hyprctl.BindLua("Escape", hyprctl.DspSubmap("reset"), hyprctl.BindOptions{Description: "Senda: cancelar grabación de atajo"}))

// StopCapture returns to the default submap. It is safe to call repeatedly.
func StopCapture(ctx context.Context, run stt.Runner) error {
	return dispatchSubmap(ctx, run, "reset")
}

func dispatchSubmap(ctx context.Context, run stt.Runner, name string) error {
	if !InSession() {
		return fmt.Errorf("no hay una sesión de Hyprland")
	}
	return hyprctl.New(run).Submap(ctx, name)
}
