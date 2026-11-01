// Package session coordinates recognition, cancellation, delivery and cleanup.
package session

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type State string

const (
	Idle       State = "idle"
	Preparing  State = "preparing"
	Standby    State = "standby"
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
	InputPrepare   Input = "prepare"
	InputLoaded    Input = "loaded"
	InputStart     Input = "start"
	InputReady     Input = "ready"
	InputStop      Input = "stop"
	InputCancel    Input = "cancel"
	InputFinalized Input = "finalized"
	InputDelivered Input = "delivered"
	InputFail      Input = "fail"
)

// Machine supports idle → preparing → standby → starting for preloaded sessions.
// Stop before start cancels; stop during starting waits for the stream.
// Resident cycles return from done or cancelled to standby on loaded. Each
// start clears the previous pending stop before opening a new dictation.
type Machine struct {
	state       State
	pendingStop bool
}

func NewMachine() *Machine      { return &Machine{state: Idle} }
func (m *Machine) State() State { return m.state }
func (m *Machine) Apply(in Input) (State, error) {
	next := m.state
	switch {
	case in == InputPrepare && m.state == Idle:
		next = Preparing
	case in == InputLoaded && (m.state == Preparing || m.state == Done || m.state == Cancelled):
		next = Standby
	case in == InputStop && (m.state == Preparing || m.state == Standby):
		next = Cancelled
	case in == InputStart && (m.state == Idle || m.state == Standby):
		next = Starting
		m.pendingStop = false
	case in == InputStop && m.state == Starting:
		m.pendingStop = true
	case in == InputReady && m.state == Starting:
		next = Listening
		if m.pendingStop {
			next = Stopping
		}
	case in == InputStop && m.state == Listening:
		next = Stopping
	case in == InputStop && (m.state == Stopping || m.state == Delivering):
	case in == InputFinalized && m.state == Stopping:
		next = Delivering
	case in == InputDelivered && m.state == Delivering:
		next = Done
	case (in == InputCancel || in == InputFail) && (m.state == Preparing || m.state == Standby || m.state == Starting || m.state == Listening || m.state == Stopping || m.state == Delivering):
		next = Cancelled
		if in == InputFail {
			next = Failed
		}
	default:
		return m.state, fmt.Errorf("transición de dictado no válida: %s → %s", m.state, in)
	}
	m.state = next
	return next, nil
}

type Deps struct {
	// DuckAudio returns cleanup for one active dictation, never standby.
	DuckAudio func(context.Context) (func(context.Context) error, error)
	// MuteDiscord mutes Discord before the microphone opens and returns the restoration, or nil when it changed nothing.
	MuteDiscord    func(context.Context) func(context.Context) error
	Engine         stt.Engine
	Deliverer      stt.Deliverer
	Submap         stt.Submap
	Notifier       stt.Notifier
	Settings       stt.Settings
	ModelDir       string
	CleanupTimeout time.Duration
	// StopTimeout bounds the final decode; zero uses CleanupTimeout.
	StopTimeout time.Duration
	// Standby keeps the prepared engine resident across successive dictations.
	Standby bool
}

const deliveryTimeout = 5 * time.Second

// guarded converts adapter panics into session errors, including in workers.
func guarded[T any](fn func() (T, error)) (value T, err error) {
	defer func() {
		if p := recover(); p != nil {
			err = fmt.Errorf("fallo inesperado del dictado: %v", p)
		}
	}()
	return fn()
}

// bounded also bounds adapters that fail to honor their context deadline.
func bounded[T any](ctx context.Context, fn func() (T, error)) (T, error) {
	type result struct {
		value T
		err   error
	}
	ch := make(chan result, 1)
	go func() { v, err := guarded(fn); ch <- result{v, err} }()
	select {
	case r := <-ch:
		return r.value, r.err
	case <-ctx.Done():
		var zero T
		return zero, ctx.Err()
	}
}

func Run(ctx context.Context, deps Deps, stdin io.Reader, stdout io.Writer) (retErr error) {
	if deps.CleanupTimeout <= 0 {
		deps.CleanupTimeout = 3 * time.Second
	}
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	fresh := func() (context.Context, context.CancelFunc) {
		return context.WithTimeout(context.Background(), deps.CleanupTimeout)
	}
	cleanup := func(fn func(context.Context) error) error {
		c, done := fresh()
		defer done()
		_, err := bounded(c, func() (struct{}, error) { return struct{}{}, fn(c) })
		return err
	}
	m := NewMachine()
	if deps.Standby {
		m.Apply(InputPrepare)
	} else {
		m.Apply(InputStart)
	}
	enc := json.NewEncoder(stdout)
	emit := func(e stt.Event) error { return enc.Encode(e) }
	var standby stt.Standby
	var stream stt.Stream
	var startDone <-chan struct{}
	completed := false
	defer func() {
		if p := recover(); p != nil {
			retErr = fmt.Errorf("fallo inesperado del dictado: %v", p)
		}
		if standby != nil {
			err := cleanup(standby.Cancel)
			if !(ctx.Err() != nil && errors.Is(err, context.Canceled)) {
				retErr = errors.Join(retErr, err)
			}
		}
		cancel()
		if startDone != nil {
			waitCtx, done := fresh()
			select {
			case <-startDone:
			case <-waitCtx.Done():
				retErr = errors.Join(retErr, fmt.Errorf("no se pudo esperar al inicio del motor: %w", waitCtx.Err()))
			}
			done()
		}
		if stream != nil && !completed {
			retErr = errors.Join(retErr, cleanup(stream.Cancel))
		}
		if deps.Submap != nil {
			retErr = errors.Join(retErr, cleanup(deps.Submap.Reset))
		}
		if retErr != nil {
			m.Apply(InputFail)
			message := fmt.Sprintf("No se pudo completar el dictado: %v", retErr)
			retErr = errors.Join(retErr, emit(stt.Event{Type: stt.EventError, Message: message}))
			if deps.Notifier != nil {
				_ = cleanup(func(c context.Context) error { return deps.Notifier.Notify(c, "Error de dictado", message) })
			}
		}
	}()
	if deps.Engine == nil || deps.Submap == nil || deps.Deliverer == nil {
		return errors.New("faltan componentes de la sesión de dictado")
	}
	type command struct {
		text string
		err  error
	}
	commands := make(chan command, 16)
	go func() {
		defer close(commands)
		sc := bufio.NewScanner(stdin)
		for sc.Scan() {
			select {
			case commands <- command{text: sc.Text()}:
			case <-ctx.Done():
				return
			}
		}
		if err := sc.Err(); err != nil {
			select {
			case commands <- command{err: err}:
			case <-ctx.Done():
			}
		}
	}()
	opts := stt.EngineOptions{ModelDir: deps.ModelDir, Language: deps.Settings.Language, Provider: "auto"}
	cancelEvent := func() error {
		m.Apply(InputCancel)
		return emit(stt.Event{Type: stt.EventCancelled})
	}
	if deps.Standby {
		// Stdin orders remain queued while Prepare is in flight. Only the parent
		// signal may expire its context before the standby handle is returned.
		var prepareErr error
		standby, prepareErr = guarded(func() (stt.Standby, error) { return deps.Engine.Prepare(ctx, opts) })
		if ctx.Err() != nil && errors.Is(prepareErr, context.Canceled) {
			return cancelEvent()
		}
		if prepareErr != nil {
			return fmt.Errorf("no se pudo preparar el motor: %w", prepareErr)
		}
		if ctx.Err() != nil {
			return cancelEvent()
		}
		if standby == nil {
			return errors.New("el motor no devolvió un reposo")
		}
	}
	resume := errors.New("dictado residente completado")
	for {
		if deps.Standby {
			loaded := standby.Loaded()
			for m.State() != Starting {
				if ctx.Err() != nil {
					return cancelEvent()
				}
				select {
				case <-ctx.Done():
					return cancelEvent()
				case c, ok := <-commands:
					if c.err != nil {
						return c.err
					}
					if !ok || c.text == stt.CommandCancel || c.text == stt.CommandStop {
						return cancelEvent()
					}
					if c.text == stt.CommandStart && m.State() == Standby {
						m.Apply(InputStart)
					}
				case <-loaded:
					loaded = nil
					if err := standby.Err(); err != nil {
						if ctx.Err() != nil && errors.Is(err, context.Canceled) {
							return cancelEvent()
						}
						return fmt.Errorf("no se pudo cargar el motor: %w", err)
					}
					if ctx.Err() != nil {
						return cancelEvent()
					}
					m.Apply(InputLoaded)
					if err := emit(stt.Event{Type: stt.EventLoaded}); err != nil {
						return err
					}
				}
			}
		}
		dictate := func() (dictationErr error) {
			if deps.DuckAudio != nil {
				audioCtx, done := context.WithTimeout(ctx, deps.CleanupTimeout)
				restore, err := deps.DuckAudio(audioCtx)
				done()
				if restore != nil {
					defer func() {
						restoreErr := cleanup(restore)
						// A cleanup failure must end the resident session too.
						if restoreErr != nil {
							if errors.Is(dictationErr, resume) {
								dictationErr = nil
							}
							dictationErr = errors.Join(dictationErr, restoreErr)
						}
					}()
				}
				if err != nil {
					return err
				}
			}
			if deps.MuteDiscord != nil {
				// Discord's microphone is independent of ours: mute it in parallel so
				// the dictation starts at once, and restore only after muting finished.
				muted := make(chan func(context.Context) error, 1)
				go func() { muted <- deps.MuteDiscord(ctx) }()
				defer func() {
					// Discord problems are reported but never end the dictation.
					if restore := <-muted; restore != nil {
						if err := cleanup(restore); err != nil {
							fmt.Fprintf(os.Stderr, "Aviso: %v\n", err)
						}
					}
				}()
			}
			if err := cleanup(deps.Submap.Reset); err != nil {
				return fmt.Errorf("no se pudo limpiar el atajo de Esc: %w", err)
			}
			enterCtx, enterDone := context.WithTimeout(ctx, deps.CleanupTimeout)
			_, enterErr := bounded(enterCtx, func() (struct{}, error) {
				return struct{}{}, deps.Submap.Enter(enterCtx)
			})
			enterDone()
			if err := enterErr; err != nil {
				if errors.Is(err, stt.ErrSubmapUnavailable) {
					fmt.Fprintln(os.Stderr, "Aviso: Esc no está disponible en esta sesión.")
				} else if ctx.Err() == nil {
					return fmt.Errorf("no se pudo activar el submapa: %w", err)
				}
			}
			if ctx.Err() != nil {
				return emit(stt.Event{Type: stt.EventCancelled})
			}
			type startedResult struct {
				stream stt.Stream
				err    error
			}
			startResults := make(chan startedResult)
			var started <-chan startedResult = startResults
			doneStarting := make(chan struct{})
			startDone = doneStarting
			beginStandby := standby
			standby = nil // Begin now owns the engine; never call Standby.Cancel concurrently.
			go func() {
				defer close(doneStarting)
				s, err := guarded(func() (stt.Stream, error) {
					if beginStandby != nil {
						return beginStandby.Begin(ctx)
					}
					return deps.Engine.Start(ctx, opts)
				})
				select {
				case startResults <- startedResult{s, err}:
				case <-ctx.Done():
					if s != nil {
						_ = cleanup(s.Cancel)
					}
					if beginStandby != nil {
						_ = cleanup(beginStandby.Cancel)
					}
				}
			}()
			type stoppedResult struct {
				text string
				err  error
			}
			var stopped <-chan stoppedResult
			var stopCancel context.CancelFunc
			defer func() {
				if stopCancel != nil {
					stopCancel()
				}
			}()
			beginStop := func() {
				stopTimeout := deps.StopTimeout
				if stopTimeout <= 0 {
					stopTimeout = deps.CleanupTimeout
				}
				stopCtx, done := context.WithTimeout(context.Background(), stopTimeout)
				stopCancel = done
				ch := make(chan stoppedResult, 1)
				stopped = ch
				activeStream := stream
				go func() {
					defer done()
					text, err := bounded(stopCtx, func() (string, error) { return activeStream.Stop(stopCtx) })
					ch <- stoppedResult{text: text, err: err}
				}()
			}
			cancelled := func(resident bool) error {
				if stopCancel != nil {
					stopCancel()
				}
				if deps.Standby && started != nil && ctx.Err() == nil {
					// A stdin cancel during Begin waits for its stream without expiring
					// the Prepare context or racing Standby.Cancel against Begin.
					var r startedResult
					select {
					case r = <-started:
					case <-ctx.Done():
						return cancelEvent()
					}
					started = nil
					stream = r.stream
					standby = beginStandby
					if r.err != nil && !(ctx.Err() != nil && errors.Is(r.err, context.Canceled)) {
						return fmt.Errorf("no se pudo iniciar el motor: %w", r.err)
					}
				}
				m.Apply(InputCancel)
				// Resident shutdown releases Standby before cancelling its context.
				if !deps.Standby {
					cancel()
				}
				if stream != nil && !completed {
					completed = true
					if err := cleanup(stream.Cancel); err != nil {
						return fmt.Errorf("no se pudo cancelar el motor: %w", err)
					}
				}
				if err := emit(stt.Event{Type: stt.EventCancelled}); err != nil {
					return err
				}
				if resident && ctx.Err() == nil {
					return resume
				}
				return nil
			}
			handle := func(c command, ok bool) (bool, error) {
				if !ok || c.text == stt.CommandCancel {
					return true, cancelled(deps.Standby && ok && c.text == stt.CommandCancel)
				}
				if c.err != nil {
					return true, fmt.Errorf("no se pudieron leer las órdenes: %w", c.err)
				}
				if c.text == stt.CommandStop {
					previous := m.State()
					m.Apply(InputStop)
					if previous == Listening {
						beginStop()
					}
				}
				return false, nil
			}
			pending := func() (bool, error) {
				for {
					select {
					case c, ok := <-commands:
						if end, err := handle(c, ok); end {
							return true, err
						}
					default:
						return false, nil
					}
				}
			}
			var results <-chan stt.Result
			var activity <-chan bool
			last := ""
			partial := func(r stt.Result) error {
				if r.Text == last {
					return nil
				}
				last = r.Text
				return emit(stt.Event{Type: stt.EventPartial, Text: r.Text})
			}
			for {
				if ctx.Err() != nil {
					return cancelled(false)
				}
				// Consume already queued orders before ready/final, so cancel wins.
				if end, err := pending(); end {
					return err
				}
				select {
				case <-ctx.Done():
					return cancelled(false)
				case c, ok := <-commands:
					if end, err := handle(c, ok); end {
						return err
					}
				case r := <-started:
					started = nil
					stream = r.stream
					standby = beginStandby
					if ctx.Err() != nil {
						return cancelled(false)
					}
					if r.err != nil {
						return fmt.Errorf("no se pudo iniciar el motor: %w", r.err)
					}
					if stream == nil {
						return errors.New("el motor no devolvió una sesión")
					}
					m.Apply(InputReady)
					if err := emit(stt.Event{Type: stt.EventReady}); err != nil {
						return err
					}
					results = stream.Results()
					if source, ok := stream.(stt.ActivityStream); ok {
						activity = source.Activity()
					}
					if m.State() == Stopping {
						beginStop()
					}
				case active, ok := <-activity:
					if !ok {
						activity = nil
					} else if m.State() == Listening {
						if err := emit(stt.Event{Type: stt.EventActivity, Active: active}); err != nil {
							return err
						}
					}
				case r, ok := <-results:
					if !ok {
						results = nil
						if err := stream.Err(); err != nil {
							return fmt.Errorf("el motor de dictado falló: %w", err)
						}
						if m.State() != Stopping {
							return errors.New("El motor se detuvo inesperadamente")
						}
					} else if err := partial(r); err != nil {
						return err
					}
				case r := <-stopped:
					if ctx.Err() != nil {
						return cancelled(false)
					}
					if end, err := pending(); end {
						return err
					}
					if r.err != nil {
						return fmt.Errorf("no se pudo detener el motor: %w", r.err)
					}
					if err := stream.Err(); err != nil {
						return fmt.Errorf("el motor de dictado falló: %w", err)
					}
					// Stop closes Results. Flush its buffered tail before final.
					for results != nil {
						select {
						case p, ok := <-results:
							if !ok {
								results = nil
							} else if err := partial(p); err != nil {
								return err
							}
						default:
							results = nil
						}
					}
					if ctx.Err() != nil {
						return cancelled(false)
					}
					if end, err := pending(); end {
						return err
					}
					completed = true
					m.Apply(InputFinalized)
					if err := emit(stt.Event{Type: stt.EventFinal, Text: r.text}); err != nil {
						return err
					}
					if r.text != "" {
						deliveryCtx, done := context.WithTimeout(context.Background(), deliveryTimeout)
						_, err := bounded(deliveryCtx, func() (struct{}, error) {
							return struct{}{}, deps.Deliverer.Deliver(deliveryCtx, r.text, deps.Settings)
						})
						done()
						if err != nil {
							return fmt.Errorf("no se pudo entregar el texto: %w", err)
						}
						if err := emit(stt.Event{Type: stt.EventDelivered}); err != nil {
							return err
						}
					}
					m.Apply(InputDelivered)
					if deps.Standby {
						return resume
					}
					return nil
				}
			}
		}
		if err := dictate(); !errors.Is(err, resume) {
			return err
		}
		// The microphone is closed; remove Esc while the model stays resident.
		if err := cleanup(deps.Submap.Reset); err != nil {
			return fmt.Errorf("no se pudo limpiar el atajo de Esc: %w", err)
		}
		stream = nil
		completed = false
		startDone = nil
	}
}
