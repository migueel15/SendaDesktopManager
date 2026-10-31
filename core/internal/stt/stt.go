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
	EventActivity  EventType = "activity"
	EventPartial   EventType = "partial"
	EventFinal     EventType = "final"
	EventDelivered EventType = "delivered"
	EventCancelled EventType = "cancelled"
	EventError     EventType = "error"
)

// Event is encoded as one JSON line on the session's stdout.
type Event struct {
	Type         EventType `json:"event"`
	Text         string    `json:"text,omitempty"`
	OriginalText string    `json:"originalText,omitempty"`
	Message      string    `json:"message,omitempty"`
	Active       bool      `json:"active,omitempty"`
}

// ActivityStream optionally exposes recent microphone activity independently of transcription.
type ActivityStream interface{ Activity() <-chan bool }

// Commands are read one per line from the session's stdin.
const (
	CommandStart  = "start"
	CommandStop   = "stop"
	CommandCancel = "cancel"
)

// Result contains the complete accumulated transcription so far.
type Result struct{ Text string }

// Stream represents one dictation and closes Results when that dictation ends.
// Afterwards Err returns nil for a normal Stop/Cancel, or the asynchronous
// process/audio/decode error. Stop and Cancel are idempotent for this Stream and
// kill the process on ctx expiry. Stop returns the final text; Cancel discards it.
// A standby Stream closes the microphone but keeps the model resident on success.
type Stream interface {
	Results() <-chan Result
	Err() error
	Stop(ctx context.Context) (string, error)
	Cancel(ctx context.Context) error
}

// Standby holds a prepared engine without opening the microphone. Loaded closes
// when loading finishes, including on failure; after it closes, Err reports the
// load error (nil on success). Begin waits internally for loaded, opens the
// microphone and waits for that dictation's ready before returning a new Stream.
// After Stream.Stop returns the final text or Stream.Cancel finishes, Loaded and
// Begin are valid again for the next dictation. Loaded is rearmed for the next loaded event,
// after the microphone closes and a fresh recognition stream is created.
// Standby.Cancel terminates the process and releases the model. The session
// guarantees that Begin and Standby.Cancel are never concurrent.
//
// Session standby states: preparing → standby → starting → listening → stopping
// → delivering → standby, repeated for each dictation. Cancel while listening
// discards the text and returns to standby. Each return to standby emits loaded,
// after delivered on Stop (after final alone when the text is empty), or after
// cancelled on Cancel. A delivery or microphone failure emits error and ends
// both session and process; the shell is responsible for relaunching them.
// Cancel or Stop in standby terminates without error; signals and stdin EOF
// terminate cleanly as well.
type Standby interface {
	Loaded() <-chan struct{}
	Err() error
	Begin(ctx context.Context) (Stream, error)
	Cancel(ctx context.Context) error
}

type Engine interface {
	// Prepare loads the model without recording. The engine protocol uses
	// --standby, emits loaded and waits for start, stop or cancel on stdin.
	// Only start opens the microphone. Stop emits final, closes the microphone,
	// creates a fresh stream and emits loaded again without unloading the model;
	// cancel while listening does the same without final. Stop/cancel while idle
	// exit with code 0; stdin EOF and SIGTERM terminate the process cleanly.
	// A dictation error emits error and terminates. Without standby, Start retains
	// its single-dictation lifetime.
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
// on stderr. Reset removes that bind and is idempotent. In resident mode the
// session repeats Reset before Enter for every dictation.
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
func DetachedRunner(ctx context.Context, stdin io.Reader, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdin = stdin
	// Nil stdout and stderr use the null device, rather than Output's pipes.
	// Wait still reaps the command and reports its exit status, but does not
	// wait for a clipboard owner that inherited its output descriptors.
	return nil, cmd.Run()
}
