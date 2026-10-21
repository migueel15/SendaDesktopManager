// Package session coordinates recognition, cancellation, delivery and cleanup.
package session

import (
	"context"
	"io"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type State string

const (
	Idle       State = "idle"
	Starting   State = "starting"
	Listening  State = "listening"
	Stopping   State = "stopping"
	Delivering State = "delivering"
	Done       State = "done"
	Cancelled  State = "cancelled"
	Failed     State = "failed"
)

type Input string

const (
	InputStart     Input = "start"
	InputReady     Input = "ready"
	InputStop      Input = "stop"
	InputCancel    Input = "cancel"
	InputFinalized Input = "finalized"
	InputDelivered Input = "delivered"
	InputFail      Input = "fail"
)

type Machine struct{ state State }

func NewMachine() *Machine                    { return &Machine{state: Idle} }
func (m *Machine) State() State               { return m.state }
func (m *Machine) Apply(Input) (State, error) { return m.state, stt.ErrNotImplemented }

type Deps struct {
	Engine         stt.Engine
	Deliverer      stt.Deliverer
	Submap         stt.Submap
	Notifier       stt.Notifier
	Settings       stt.Settings
	ModelDir       string
	CleanupTimeout time.Duration
}

func Run(context.Context, Deps, io.Reader, io.Writer) error { return stt.ErrNotImplemented }
