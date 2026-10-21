// Package deliver transfers recognized text to the clipboard or focused window.
package deliver

import (
	"context"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type deliverer struct{ run stt.Runner }

func New(run stt.Runner) stt.Deliverer                                 { return &deliverer{run: run} }
func (*deliverer) Deliver(context.Context, string, stt.Settings) error { return stt.ErrNotImplemented }
