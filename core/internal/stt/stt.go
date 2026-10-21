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
	EventLoaded    EventType = "loaded"
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
	CommandStart  = "start"
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

// Standby holds a prepared engine without opening the microphone. Loaded closes
// when loading finishes, including on failure; after it closes, Err reports the
// load error (nil on success). Begin opens the microphone and returns the current
// Stream. Cancel releases the engine without delivering a transcription.
//
// Session standby states: preparing → standby → starting (start) → listening → …
// A successful load emits loaded; a failed load emits error. Cancel in preparing
// or standby terminates without error. Stop before start is equivalent to cancel.
type Standby interface {
	Loaded() <-chan struct{}
	Err() error
	Begin(ctx context.Context) (Stream, error)
	Cancel(ctx context.Context) error
}

type Engine interface {
	// Prepare loads the model without recording. The engine protocol uses
	// --standby, emits {"event":"loaded"}, then waits for start or cancel on
	// stdin before launching pw-record (only start opens the microphone).
	Prepare(ctx context.Context, opts EngineOptions) (Standby, error)
	Start(ctx context.Context, opts EngineOptions) (Stream, error)
}

// EngineOptions.Provider is "auto", "cuda" or "cpu".
type EngineOptions struct{ ModelDir, Language, Provider string }
type Deliverer interface {
	Deliver(ctx context.Context, text string, s Settings) error
}

// Submap.Enter registers a dynamic Esc bind and returns ErrSubmapUnavailable
// when the binds module is absent. The session continues without Esc and warns
// on stderr. Reset removes that bind and is idempotent.
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

// DetachedRunner executes a command without waiting for background children to
// close inherited stdout. It has the same call signature as Runner.
// Implementation is deferred to the delivery adapter task.
func DetachedRunner(ctx context.Context, stdin io.Reader, name string, args ...string) ([]byte, error) {
	return nil, ErrNotImplemented
}
