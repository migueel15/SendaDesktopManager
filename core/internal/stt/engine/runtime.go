package engine

import (
	"context"
	"io"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// Runtime queries return zero values until runtime installation is implemented.
func RuntimeInstalled() bool                          { return false }
func RuntimeProvider() string                         { return "" }
func Python() string                                  { return "" }
func InstallRuntime(context.Context, io.Writer) error { return stt.ErrNotImplemented }
