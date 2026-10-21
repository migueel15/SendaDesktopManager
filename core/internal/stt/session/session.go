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

type Machine struct {
	state       State
	pendingStop bool
}

func NewMachine() *Machine      { return &Machine{state: Idle} }
func (m *Machine) State() State { return m.state }
func (m *Machine) Apply(in Input) (State, error) {
	next := m.state
	switch {
	case in == InputStart && m.state == Idle:
		next = Starting
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
	case (in == InputCancel || in == InputFail) && (m.state == Starting || m.state == Listening || m.state == Stopping || m.state == Delivering):
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
	Engine         stt.Engine
	Deliverer      stt.Deliverer
	Submap         stt.Submap
	Notifier       stt.Notifier
	Settings       stt.Settings
	ModelDir       string
	CleanupTimeout time.Duration
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
	m.Apply(InputStart)
	enc := json.NewEncoder(stdout)
	emit := func(e stt.Event) error { return enc.Encode(e) }
	var stream stt.Stream
	var startDone <-chan struct{}
	completed := false
	defer func() {
		if p := recover(); p != nil {
			retErr = fmt.Errorf("fallo inesperado del dictado: %v", p)
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
	enterCtx, enterDone := context.WithTimeout(ctx, deps.CleanupTimeout)
	_, enterErr := bounded(enterCtx, func() (struct{}, error) {
		return struct{}{}, deps.Submap.Enter(enterCtx)
	})
	enterDone()
	if err := enterErr; err != nil {
		if errors.Is(err, stt.ErrSubmapUnavailable) {
			fmt.Fprintln(os.Stderr, "Aviso: el módulo de atajos de Senda no está cargado; Esc no está disponible.")
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
	go func() {
		defer close(doneStarting)
		s, err := guarded(func() (stt.Stream, error) {
			return deps.Engine.Start(ctx, stt.EngineOptions{ModelDir: deps.ModelDir, Language: deps.Settings.Language, Provider: "auto"})
		})
		select {
		case startResults <- startedResult{s, err}:
		case <-ctx.Done():
			if s != nil {
				_ = cleanup(s.Cancel)
			}
		}
	}()
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
		stopCtx, done := fresh()
		stopCancel = done
		ch := make(chan stoppedResult, 1)
		stopped = ch
		go func() {
			text, err := bounded(stopCtx, func() (string, error) { return stream.Stop(stopCtx) })
			ch <- stoppedResult{text, err}
		}()
	}
	cancelled := func() error {
		m.Apply(InputCancel)
		cancel()
		if stream != nil && !completed {
			completed = true
			if err := cleanup(stream.Cancel); err != nil {
				return fmt.Errorf("no se pudo cancelar el motor: %w", err)
			}
		}
		return emit(stt.Event{Type: stt.EventCancelled})
	}
	handle := func(c command, ok bool) (bool, error) {
		if !ok || c.text == stt.CommandCancel {
			return true, cancelled()
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
			return cancelled()
		}
		// Consume already queued orders before ready/final, so cancel wins.
		if end, err := pending(); end {
			return err
		}
		select {
		case <-ctx.Done():
			return cancelled()
		case c, ok := <-commands:
			if end, err := handle(c, ok); end {
				return err
			}
		case r := <-started:
			started = nil
			stream = r.stream
			if ctx.Err() != nil {
				return cancelled()
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
			if m.State() == Stopping {
				beginStop()
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
				return cancelled()
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
				return cancelled()
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
			return nil
		}
	}
}
