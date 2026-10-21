// Package stt defines settings, paths and ports shared by speech-to-text adapters.
package stt

import (
	"context"
	"errors"
	"io"
	"os/exec"
)

var ErrNotImplemented = errors.New("not implemented")
var ErrSubmapUnavailable = errors.New("el módulo de atajos de Senda no está cargado")

type EventType string

const (
	EventReady     EventType = "ready"
	EventPartial   EventType = "partial"
	EventFinal     EventType = "final"
	EventDelivered EventType = "delivered"
	EventCancelled EventType = "cancelled"
	EventError     EventType = "error"
)

// Event is encoded as one JSON line on the session's stdout.
type Event struct {
	Type    EventType `json:"event"`
	Text    string    `json:"text,omitempty"`
	Message string    `json:"message,omitempty"`
}

// Commands are read one per line from the session's stdin.
const (
	CommandStop   = "stop"
	CommandCancel = "cancel"
)

// Result contains the complete accumulated transcription so far.
type Result struct{ Text string }

// Stream closes Results when the engine ends for any reason. Afterwards Err
// returns nil for a normal Stop/Cancel, or the asynchronous process/audio/decode
// error. Stop and Cancel are idempotent and kill the process on ctx expiry.
type Stream interface {
	Results() <-chan Result
	Err() error
	Stop(ctx context.Context) (string, error)
	Cancel(ctx context.Context) error
}

type Engine interface {
	Start(ctx context.Context, opts EngineOptions) (Stream, error)
}

// EngineOptions.Provider is "auto", "cuda" or "cpu".
type EngineOptions struct{ ModelDir, Language, Provider string }
type Deliverer interface {
	Deliver(ctx context.Context, text string, s Settings) error
}

// Submap.Enter returns ErrSubmapUnavailable when the binds module is absent.
// The session continues without Esc and warns on stderr. Reset is idempotent.
type Submap interface {
	Enter(ctx context.Context) error
	Reset(ctx context.Context) error
}
type Notifier interface {
	Notify(ctx context.Context, summary, body string) error
}

// Runner executes an external command; stdin may be nil.
type Runner func(ctx context.Context, stdin io.Reader, name string, args ...string) ([]byte, error)

func ExecRunner(ctx context.Context, stdin io.Reader, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdin = stdin
	return cmd.Output()
}
