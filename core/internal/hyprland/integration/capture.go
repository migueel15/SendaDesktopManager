package integration

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// StartCapture enters the empty capture submap so that Hyprland does not
// consume the shortcut being recorded.
func StartCapture(ctx context.Context, run stt.Runner) error {
	if !InSession() {
		return fmt.Errorf("no hay una sesión de Hyprland")
	}
	if run == nil {
		run = stt.ExecRunner
	}
	// Define the submap on the fly, so recording does not depend on the
	// version of the loaded module. Redefining it is harmless.
	out, err := run(ctx, nil, "hyprctl", "eval", captureSubmapLua)
	if text := strings.TrimSpace(string(out)); err != nil || text != "ok" {
		return fmt.Errorf("definir el modo de grabación: %s: %v", text, err)
	}
	return dispatchSubmap(ctx, run, CaptureSubmap)
}

// captureSubmapLua defines the capture submap: only Escape, which leaves it.
var captureSubmapLua = `hl.define_submap(` + strconv.Quote(CaptureSubmap) + `, function()
	hl.bind("Escape", hl.dsp.submap("reset"), { description = "Senda: cancelar grabación de atajo" })
end)`

// StopCapture returns to the default submap. It is safe to call repeatedly.
func StopCapture(ctx context.Context, run stt.Runner) error {
	return dispatchSubmap(ctx, run, "reset")
}

func dispatchSubmap(ctx context.Context, run stt.Runner, name string) error {
	if !InSession() {
		return fmt.Errorf("no hay una sesión de Hyprland")
	}
	if run == nil {
		run = stt.ExecRunner
	}
	out, err := run(ctx, nil, "hyprctl", "dispatch", "hl.dsp.submap("+strconv.Quote(name)+")")
	text := strings.TrimSpace(string(out))
	if err != nil || text != "ok" {
		return fmt.Errorf("hyprctl dispatch: %s: %v", text, err)
	}
	return nil
}
