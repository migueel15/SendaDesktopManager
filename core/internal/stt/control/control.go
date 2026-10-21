// Package control provides preflight checks, shell IPC control and notifications.
//
// Shell IPC target "stt" exposes toggle(): string, cancel(): bool, and
// status(): string ("idle" or the current session state). With no session,
// toggle starts one and returns "started". In starting/listening it sends stop
// once and returns "stopping"; in stopping/delivering it is a no-op returning
// "stopping". A stop received during starting is applied when the engine is
// ready; empty text is never delivered.
package control

import (
	"context"
	"errors"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type Checks struct {
	ModelInstalled   func(id string) bool
	RuntimeInstalled func() bool
	Microphone       func(ctx context.Context) error
}

var ErrNoModel = errors.New("no hay modelo instalado; ejecuta senda stt models install <id>")
var ErrNoRuntime = errors.New("el motor no está instalado; ejecuta senda stt runtime install")
var ErrNoMicrophone = errors.New("no hay micrófono disponible; conecta uno y comprueba la entrada de PipeWire")

func Preflight(context.Context, stt.Settings, Checks) error { return stt.ErrNotImplemented }

// Shell.Call invokes function on IPC target "stt".
type Shell interface {
	Call(ctx context.Context, function string) (string, error)
}

// Toggle checks status and runs preflight only when idle, before toggling.
func Toggle(context.Context, Shell, func() error) (string, error) { return "", stt.ErrNotImplemented }
func Cancel(context.Context, Shell) error                         { return stt.ErrNotImplemented }

type notifier struct{}

// NewNotifier will use D-Bus org.freedesktop.Notifications via godbus.
func NewNotifier() stt.Notifier                                { return &notifier{} }
func (*notifier) Notify(context.Context, string, string) error { return stt.ErrNotImplemented }
