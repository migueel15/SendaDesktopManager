package session

import (
	"context"
	"errors"
	"fmt"
	"io"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestMachinePendingStopAndCancellation(t *testing.T) {
	for _, state := range []State{Starting, Listening, Stopping} {
		t.Run(string(state), func(t *testing.T) {
			m := NewMachine()
			m.Apply(InputStart)
			if state != Starting {
				m.Apply(InputReady)
			}
			if state == Stopping {
				m.Apply(InputStop)
			}
			for range 2 {
				if _, err := m.Apply(InputStop); err != nil {
					t.Fatal(err)
				}
			}
			if got, err := m.Apply(InputCancel); err != nil || got != Cancelled {
				t.Fatalf("cancel = %s, %v", got, err)
			}
			if _, err := m.Apply(InputReady); err == nil {
				t.Fatal("cancelled machine accepted ready")
			}
		})
	}
	m := NewMachine()
	m.Apply(InputStart)
	m.Apply(InputStop)
	if got, err := m.Apply(InputReady); err != nil || got != Stopping {
		t.Fatalf("pending stop = %s, %v", got, err)
	}
}

func TestCancelWinsPendingStop(t *testing.T) {
	r := newRig(&fakeEngine{release: make(chan struct{})}, newStream("ignored"))
	run := start(t, context.Background(), r.deps)
	run.send(stt.CommandStop)
	run.send(stt.CommandCancel)
	run.wait(t)
	assertNoDelivery(t, r)
	if got := types(run.out.events(t)); !slices.Equal(got, []stt.EventType{stt.EventCancelled}) {
		t.Fatalf("events = %v", got)
	}
	assertResetWithLiveContext(t, r)
}

func TestEOFAndContextDuringStarting(t *testing.T) {
	for _, eof := range []bool{true, false} {
		r := newRig(&fakeEngine{release: make(chan struct{})}, newStream("ignored"))
		run := start(t, context.Background(), r.deps)
		if eof {
			run.stdin.Close()
		} else {
			run.cancel()
		}
		run.wait(t)
		assertNoDelivery(t, r)
		if !has(run.out.events(t), stt.EventCancelled) {
			t.Fatal("missing cancelled")
		}
		assertResetWithLiveContext(t, r)
	}
}

type engineFunc func(context.Context, stt.EngineOptions) (stt.Stream, error)

func (engineFunc) Prepare(context.Context, stt.EngineOptions) (stt.Standby, error) {
	return nil, stt.ErrNotImplemented
}

func (f engineFunc) Start(ctx context.Context, o stt.EngineOptions) (stt.Stream, error) {
	return f(ctx, o)
}

type heldStream struct {
	*fakeStream
	entered   chan context.Context
	release   chan struct{}
	cancelled chan context.Context
	once      sync.Once
}

func newHeldStream() *heldStream {
	return &heldStream{fakeStream: newStream("final"), entered: make(chan context.Context, 1), release: make(chan struct{}), cancelled: make(chan context.Context, 1)}
}
func (s *heldStream) Stop(ctx context.Context) (string, error) {
	s.entered <- ctx
	<-s.release // Deliberately ignore cancellation to test the outer deadline.
	return s.fakeStream.Stop(ctx)
}
func (s *heldStream) Cancel(ctx context.Context) error {
	s.cancelled <- ctx
	return s.fakeStream.Cancel(ctx)
}
func (s *heldStream) unblock() { s.once.Do(func() { close(s.release) }) }

func heldRig(s *heldStream) *rig {
	r := newRig(&fakeEngine{}, s.fakeStream)
	r.deps.Engine = engineFunc(func(context.Context, stt.EngineOptions) (stt.Stream, error) { return s, nil })
	return r
}

func TestCancelWhileStopping(t *testing.T) {
	for _, cause := range []string{"command", "eof", "context"} {
		t.Run(cause, func(t *testing.T) {
			s := newHeldStream()
			defer s.unblock()
			r := heldRig(s)
			run := start(t, context.Background(), r.deps)
			run.waitEvent(t, stt.EventReady)
			run.send(stt.CommandStop)
			select {
			case ctx := <-s.entered:
				assertCleanupContext(t, ctx)
			case <-time.After(time.Second):
				t.Fatal("stop not called")
			}
			run.send(stt.CommandStop)
			switch cause {
			case "command":
				run.send(stt.CommandCancel)
			case "eof":
				run.stdin.Close()
			case "context":
				run.cancel()
			}
			run.wait(t)
			assertNoDelivery(t, r)
			if !has(run.out.events(t), stt.EventCancelled) || has(run.out.events(t), stt.EventFinal) {
				t.Fatal(types(run.out.events(t)))
			}
			select {
			case ctx := <-s.cancelled:
				if _, ok := ctx.Deadline(); !ok {
					t.Fatal("cancel has no deadline")
				}
			default:
				t.Fatal("cancel not called")
			}
			assertResetWithLiveContext(t, r)
		})
	}
}

func assertCleanupContext(t *testing.T, ctx context.Context) {
	t.Helper()
	if ctx.Err() != nil {
		t.Fatal("cleanup context already cancelled")
	}
	if _, ok := ctx.Deadline(); !ok {
		t.Fatal("cleanup has no deadline")
	}
}

func TestUnresponsiveStopHasBoundedCleanup(t *testing.T) {
	s := newHeldStream()
	defer s.unblock()
	r := heldRig(s)
	r.deps.CleanupTimeout = 30 * time.Millisecond
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	before := time.Now()
	run.send(stt.CommandStop)
	run.wait(t)
	if elapsed := time.Since(before); elapsed > 500*time.Millisecond {
		t.Fatalf("cleanup took %s", elapsed)
	}
	assertNoDelivery(t, r)
	if !has(run.out.events(t), stt.EventError) || r.notif.count() != 1 {
		t.Fatal("missing single error notification")
	}
	assertResetWithLiveContext(t, r)
}

func TestRepeatedStopWhileStoppingDeliversOnce(t *testing.T) {
	s := newHeldStream()
	defer s.unblock()
	r := heldRig(s)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	<-s.entered
	run.send(stt.CommandStop)
	s.unblock()
	run.wait(t)
	if stops, _ := s.counts(); stops != 1 {
		t.Fatalf("stops = %d", stops)
	}
	if len(r.deliv.delivered()) != 1 {
		t.Fatal(r.deliv.delivered())
	}
}

func TestEmptyFinalAndDuplicatePartials(t *testing.T) {
	s := newStream("")
	r := newRig(&fakeEngine{}, s)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	for _, text := range []string{"hola", "hola", "hola mundo", ""} {
		s.results <- stt.Result{Text: text}
	}
	run.waitPartialCount(t, 3)
	run.send(stt.CommandStop)
	run.wait(t)
	assertNoDelivery(t, r)
	var partials []string
	for _, e := range run.out.events(t) {
		if e.Type == stt.EventPartial {
			partials = append(partials, e.Text)
		}
	}
	if !slices.Equal(partials, []string{"hola", "hola mundo", ""}) {
		t.Fatal(partials)
	}
	if !has(run.out.events(t), stt.EventFinal) || has(run.out.events(t), stt.EventDelivered) {
		t.Fatal(types(run.out.events(t)))
	}
}

func TestAsyncFailureWhileStoppingNotifiesOnce(t *testing.T) {
	s := newHeldStream()
	defer s.unblock()
	r := heldRig(s)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	<-s.entered
	s.fail(errors.New("fallo de audio"))
	s.unblock()
	run.wait(t)
	assertNoDelivery(t, r)
	if r.notif.count() != 1 || !has(run.out.events(t), stt.EventError) {
		t.Fatal("missing single error")
	}
}

func TestEnginePanicResetsSubmap(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream(""))
	r.deps.Engine = engineFunc(func(context.Context, stt.EngineOptions) (stt.Stream, error) { panic("motor") })
	run := start(t, context.Background(), r.deps)
	run.wait(t)
	assertResetWithLiveContext(t, r)
	if r.notif.count() != 1 || !has(run.out.events(t), stt.EventError) {
		t.Fatal("missing panic error")
	}
}

type submapFunc struct {
	*fakeSubmap
	enter func(context.Context) error
}

func (s submapFunc) Enter(ctx context.Context) error { return s.enter(ctx) }

func TestEnterPanicResetsSubmap(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream(""))
	r.deps.Submap = submapFunc{r.submap, func(context.Context) error { panic("submapa") }}
	run := start(t, context.Background(), r.deps)
	run.wait(t)
	assertResetWithLiveContext(t, r)
	if r.notif.count() != 1 {
		t.Fatal("panic was not notified")
	}
}

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) { return 0, io.ErrClosedPipe }
func TestOutputFailureCancelsStream(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream("ignored"))
	in := newBufPipe()
	defer in.Close()
	if err := Run(context.Background(), r.deps, in, failingWriter{}); !errors.Is(err, io.ErrClosedPipe) {
		t.Fatal(err)
	}
	if _, cancels := r.stream.counts(); cancels != 1 {
		t.Fatal("stream not cancelled")
	}
	assertNoDelivery(t, r)
	assertResetWithLiveContext(t, r)
}

func TestStopFlushesBufferedPartialsBeforeFinal(t *testing.T) {
	s := newStream("final")
	r := newRig(&fakeEngine{release: make(chan struct{})}, s)
	engine := r.deps.Engine.(*fakeEngine)
	for _, text := range []string{"uno", "dos", "tres"} {
		s.results <- stt.Result{Text: text}
	}
	run := start(t, context.Background(), r.deps)
	run.send(stt.CommandStop)
	close(engine.release)
	run.wait(t)
	var texts []string
	final := false
	for _, event := range run.out.events(t) {
		if event.Type == stt.EventFinal {
			final = true
		}
		if event.Type == stt.EventPartial {
			if final {
				t.Fatal("partial after final")
			}
			texts = append(texts, event.Text)
		}
	}
	if !slices.Equal(texts, []string{"uno", "dos", "tres"}) {
		t.Fatalf("partials = %v", texts)
	}
}

func TestCancelledStartWaitsForLateStream(t *testing.T) {
	for _, afterDeadline := range []bool{false, true} {
		t.Run(fmt.Sprintf("after-deadline=%t", afterDeadline), func(t *testing.T) {
			r := newRig(&fakeEngine{}, newStream("ignored"))
			r.deps.CleanupTimeout = 50 * time.Millisecond
			entered := make(chan struct{})
			cancelledStart := make(chan struct{})
			release := make(chan struct{})
			var once sync.Once
			unblock := func() { once.Do(func() { close(release) }) }
			defer unblock()
			r.deps.Engine = engineFunc(func(ctx context.Context, _ stt.EngineOptions) (stt.Stream, error) {
				close(entered)
				<-ctx.Done()
				close(cancelledStart)
				<-release // Simulate Start returning a stream after cancellation.
				return r.stream, nil
			})
			run := start(t, context.Background(), r.deps)
			<-entered
			run.cancel()
			<-cancelledStart
			if afterDeadline {
				before := time.Now()
				run.wait(t)
				if elapsed := time.Since(before); elapsed > 500*time.Millisecond {
					t.Fatalf("waiting for Start took %s", elapsed)
				}
			} else {
				select {
				case <-run.done:
					t.Fatal("Run returned before the starting worker finished")
				case <-time.After(10 * time.Millisecond):
				}
			}
			unblock()
			if !afterDeadline {
				run.wait(t)
			}
			deadline := time.After(time.Second)
			for {
				if _, cancels := r.stream.counts(); cancels == 1 {
					break
				}
				select {
				case <-deadline:
					t.Fatal("late stream was not cancelled")
				case <-time.After(time.Millisecond):
				}
			}
			assertNoDelivery(t, r)
			assertResetWithLiveContext(t, r)
		})
	}
}

func TestUnexpectedResultsClosureNotifiesOnce(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream("ignored"))
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	r.stream.close()
	run.wait(t)
	if got := types(run.out.events(t)); !slices.Equal(got, []stt.EventType{stt.EventReady, stt.EventError}) {
		t.Fatalf("events = %v", got)
	}
	if events := run.out.events(t); !strings.Contains(events[1].Message, "El motor se detuvo inesperadamente") {
		t.Fatalf("error = %q", events[1].Message)
	}
	if r.notif.count() != 1 {
		t.Fatal("unexpected closure was not notified exactly once")
	}
	assertNoDelivery(t, r)
	assertResetWithLiveContext(t, r)
}

func TestUnresponsiveEnterHasDeadline(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream("ignored"))
	r.deps.CleanupTimeout = 30 * time.Millisecond
	release := make(chan struct{})
	defer close(release)
	entered := make(chan context.Context, 1)
	r.deps.Submap = submapFunc{r.submap, func(ctx context.Context) error {
		entered <- ctx
		<-release // Deliberately ignore the deadline.
		return nil
	}}
	engineCalled := make(chan struct{}, 1)
	r.deps.Engine = engineFunc(func(context.Context, stt.EngineOptions) (stt.Stream, error) {
		engineCalled <- struct{}{}
		return r.stream, nil
	})
	before := time.Now()
	run := start(t, context.Background(), r.deps)
	assertCleanupContext(t, <-entered)
	run.wait(t)
	if elapsed := time.Since(before); elapsed > 500*time.Millisecond {
		t.Fatalf("Enter took %s", elapsed)
	}
	select {
	case <-engineCalled:
		t.Fatal("engine started after Enter timed out")
	default:
	}
	if !has(run.out.events(t), stt.EventError) || r.notif.count() != 1 {
		t.Fatal("Enter timeout was not notified exactly once")
	}
	assertResetWithLiveContext(t, r)
}

type deliverFunc func(context.Context, string, stt.Settings) error

func (f deliverFunc) Deliver(ctx context.Context, text string, settings stt.Settings) error {
	return f(ctx, text, settings)
}

func TestDeliveryFinishesAfterCancellation(t *testing.T) {
	for _, cause := range []string{"command", "eof", "context", "delivery-error"} {
		t.Run(cause, func(t *testing.T) {
			r := newRig(&fakeEngine{}, newStream("texto"))
			entered := make(chan context.Context, 1)
			release := make(chan struct{})
			var once sync.Once
			unblock := func() { once.Do(func() { close(release) }) }
			defer unblock()
			r.deps.Deliverer = deliverFunc(func(ctx context.Context, text string, _ stt.Settings) error {
				entered <- ctx
				<-release
				if cause == "delivery-error" {
					return errors.New("fallo de entrega")
				}
				return r.deliv.Deliver(ctx, text, r.deps.Settings)
			})
			run := start(t, context.Background(), r.deps)
			run.waitEvent(t, stt.EventReady)
			run.send(stt.CommandStop)
			deliveryCtx := <-entered
			assertCleanupContext(t, deliveryCtx)
			switch cause {
			case "command":
				run.send(stt.CommandCancel)
			case "eof":
				run.stdin.Close()
			default:
				run.cancel()
			}
			if err := deliveryCtx.Err(); err != nil {
				t.Fatalf("delivery cancelled by session: %v", err)
			}
			unblock()
			run.wait(t)
			want := []stt.EventType{stt.EventReady, stt.EventFinal, stt.EventDelivered}
			wantNotifications := 0
			if cause == "delivery-error" {
				want[2] = stt.EventError
				wantNotifications = 1
			} else if got := r.deliv.delivered(); !slices.Equal(got, []string{"texto"}) {
				t.Fatalf("delivered = %v", got)
			}
			if got := types(run.out.events(t)); !slices.Equal(got, want) {
				t.Fatalf("events = %v, want %v", got, want)
			}
			if r.notif.count() != wantNotifications {
				t.Fatalf("notifications = %d", r.notif.count())
			}
			assertResetWithLiveContext(t, r)
		})
	}
}

func TestUnresponsiveDeliveryHasDeadline(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream("texto"))
	release := make(chan struct{})
	defer close(release)
	entered := make(chan context.Context, 1)
	r.deps.Deliverer = deliverFunc(func(ctx context.Context, _ string, _ stt.Settings) error {
		entered <- ctx
		<-release
		return nil
	})
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	deliveryCtx := <-entered
	deadline, ok := deliveryCtx.Deadline()
	if !ok || time.Until(deadline) > 5*time.Second {
		t.Fatal("delivery has no five-second deadline")
	}
	before := time.Now()
	select {
	case err := <-run.done:
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Fatalf("Run = %v", err)
		}
	case <-time.After(6 * time.Second):
		t.Fatal("delivery exceeded its deadline")
	}
	if elapsed := time.Since(before); elapsed > 5500*time.Millisecond {
		t.Fatalf("delivery took %s", elapsed)
	}
	if got := types(run.out.events(t)); !slices.Equal(got, []stt.EventType{stt.EventReady, stt.EventFinal, stt.EventError}) {
		t.Fatalf("events = %v", got)
	}
	if r.notif.count() != 1 {
		t.Fatal("delivery timeout was not notified exactly once")
	}
	assertResetWithLiveContext(t, r)
}

type standbyEngineFunc func(context.Context) (stt.Standby, error)

func (f standbyEngineFunc) Prepare(ctx context.Context, _ stt.EngineOptions) (stt.Standby, error) {
	return f(ctx)
}
func (standbyEngineFunc) Start(context.Context, stt.EngineOptions) (stt.Stream, error) {
	panic("standby must use Begin")
}

type lifecycleStandby struct {
	*f002Standby
	begin  func(context.Context) (stt.Stream, error)
	cancel func(context.Context) error
}

func (s lifecycleStandby) Begin(ctx context.Context) (stt.Stream, error) { return s.begin(ctx) }
func (s lifecycleStandby) Cancel(ctx context.Context) error              { return s.cancel(ctx) }

func await[T any](t *testing.T, ch <-chan T) T {
	t.Helper()
	select {
	case v := <-ch:
		return v
	case <-time.After(time.Second):
		t.Fatal("operation timed out")
		var zero T
		return zero
	}
}

func assertCleanCancellation(t *testing.T, run *running, r *rig) {
	t.Helper()
	if err := await(t, run.done); err != nil {
		t.Fatalf("Run = %v", err)
	}
	events := run.out.events(t)
	if !has(events, stt.EventCancelled) || has(events, stt.EventError) || r.notif.count() != 0 {
		t.Fatalf("events = %v, notifications = %d", events, r.notif.count())
	}
	assertNoDelivery(t, r)
}

func TestStandbyParentCancellation(t *testing.T) {
	for _, phase := range []string{"prepare-call", "loading", "standby"} {
		t.Run(phase, func(t *testing.T) {
			r := newRig(&fakeEngine{}, newStream("ignored"))
			r.deps.Standby = true
			entered := make(chan struct{})
			s := &f002Standby{loaded: make(chan struct{}), stream: r.stream}
			if phase == "standby" {
				close(s.loaded)
			}
			r.deps.Engine = standbyEngineFunc(func(ctx context.Context) (stt.Standby, error) {
				close(entered)
				if phase == "prepare-call" {
					<-ctx.Done()
					return nil, context.Canceled
				}
				return lifecycleStandby{f002Standby: s, cancel: func(context.Context) error { return context.Canceled }}, nil
			})
			run := start(t, context.Background(), r.deps)
			await(t, entered)
			if phase == "standby" {
				run.waitEvent(t, stt.EventLoaded)
			}
			run.cancel()
			assertCleanCancellation(t, run, r)
		})
	}
}

func TestStandbyCancelDuringPrepareKeepsContextAlive(t *testing.T) {
	for _, command := range []string{stt.CommandCancel, stt.CommandStop} {
		t.Run(command, func(t *testing.T) {
			r := newRig(&fakeEngine{}, newStream("ignored"))
			r.deps.Standby = true
			entered := make(chan context.Context, 1)
			release := make(chan struct{})
			cancelled := make(chan error, 1)
			s := &f002Standby{loaded: make(chan struct{}), stream: r.stream}
			r.deps.Engine = standbyEngineFunc(func(ctx context.Context) (stt.Standby, error) {
				entered <- ctx
				<-release
				return lifecycleStandby{f002Standby: s, cancel: func(cleanupCtx context.Context) error {
					cancelled <- errors.Join(ctx.Err(), cleanupCtx.Err())
					return nil
				}}, nil
			})
			run := start(t, context.Background(), r.deps)
			prepareCtx := await(t, entered)
			run.send(command)
			select {
			case <-prepareCtx.Done():
				t.Fatal("Prepare cancelled before Standby.Cancel")
			case <-time.After(20 * time.Millisecond):
			}
			close(release)
			assertCleanCancellation(t, run, r)
			if err := await(t, cancelled); err != nil {
				t.Fatalf("Cancel received expired contexts: %v", err)
			}
			if prepareCtx.Err() == nil {
				t.Fatal("session context was not released")
			}
		})
	}
}

func TestStandbyCancelDuringBeginWaitsForStream(t *testing.T) {
	for _, fail := range []bool{false, true} {
		t.Run(fmt.Sprintf("begin-fails=%t", fail), func(t *testing.T) {
			r := newRig(&fakeEngine{}, newStream("ignored"))
			r.deps.Standby = true
			entered := make(chan context.Context, 1)
			release := make(chan struct{})
			s := &f002Standby{loaded: make(chan struct{}), stream: r.stream}
			close(s.loaded)
			beginErr := errors.New("Begin failed")
			r.deps.Engine = standbyEngineFunc(func(context.Context) (stt.Standby, error) {
				return lifecycleStandby{f002Standby: s, cancel: s.Cancel, begin: func(ctx context.Context) (stt.Stream, error) {
					entered <- ctx
					<-release
					if fail {
						return nil, beginErr
					}
					s.mu.Lock()
					s.loaded = make(chan struct{})
					s.mu.Unlock()
					return &f002StandbyStream{fakeStream: r.stream, standby: s}, nil
				}}, nil
			})
			run := start(t, context.Background(), r.deps)
			run.waitEvent(t, stt.EventLoaded)
			run.send(stt.CommandStart)
			beginCtx := await(t, entered)
			run.send(stt.CommandCancel)
			select {
			case <-beginCtx.Done():
				t.Fatal("Begin context cancelled by stdin before return")
			case <-time.After(20 * time.Millisecond):
			}
			if s.cancels.Load() != 0 {
				t.Fatal("Standby.Cancel raced with Begin")
			}
			close(release)
			if fail {
				if err := await(t, run.done); !errors.Is(err, beginErr) {
					t.Fatalf("Run = %v", err)
				}
				if !has(run.out.events(t), stt.EventError) || r.notif.count() != 1 {
					t.Fatal("missing Begin failure")
				}
			} else {
				waitResidentEvent(t, run, stt.EventLoaded, 2)
				if s.cancels.Load() != 0 || beginCtx.Err() != nil {
					t.Fatal("resident cancel released the prepared engine")
				}
				run.send(stt.CommandCancel)
				assertCleanCancellation(t, run, r)
				if _, n := r.stream.counts(); n != 1 {
					t.Fatalf("Stream.Cancel calls = %d", n)
				}
			}
			if s.cancels.Load() != 1 {
				t.Fatalf("Standby.Cancel calls on shutdown = %d", s.cancels.Load())
			}
		})
	}
}

func TestMachineStandbyTransitions(t *testing.T) {
	for _, exit := range []Input{InputStart, InputStop, InputCancel, InputFail} {
		m := NewMachine()
		for _, in := range []Input{InputPrepare, InputLoaded, exit} {
			if _, err := m.Apply(in); err != nil {
				t.Fatal(err)
			}
		}
		want := map[Input]State{InputStart: Starting, InputStop: Cancelled, InputCancel: Cancelled, InputFail: Failed}[exit]
		if m.State() != want {
			t.Fatalf("state = %s, want %s", m.State(), want)
		}
	}
}

func TestResidentEmptyFinalReturnsToLoaded(t *testing.T) {
	s := &residentStandby{loaded: make(chan struct{})}
	close(s.loaded)
	s.streams = []*residentStream{{fakeStream: newStream(""), standby: s}}
	e := &residentEngine{standby: s}
	r := newRig(&fakeEngine{}, s.streams[0].fakeStream)
	r.deps.Engine, r.deps.Standby = e, true
	run := start(t, context.Background(), r.deps)
	waitResidentEvent(t, run, stt.EventLoaded, 1)
	run.send(stt.CommandStart)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	waitResidentEvent(t, run, stt.EventLoaded, 2)
	finishResident(t, run, e, stt.CommandStop, 1)
	want := []stt.EventType{stt.EventLoaded, stt.EventReady, stt.EventFinal, stt.EventLoaded, stt.EventCancelled}
	if got := types(run.out.events(t)); !slices.Equal(got, want) {
		t.Fatalf("events = %v; want %v", got, want)
	}
	assertNoDelivery(t, r)
}

func TestResidentDeliveryFailureTerminates(t *testing.T) {
	s := &residentStandby{loaded: make(chan struct{})}
	close(s.loaded)
	s.streams = []*residentStream{{fakeStream: newStream("texto"), standby: s}}
	e := &residentEngine{standby: s}
	r := newRig(&fakeEngine{}, s.streams[0].fakeStream)
	r.deps.Engine, r.deps.Standby = e, true
	deliveryErr := errors.New("fallo de entrega")
	r.deps.Deliverer = deliverFunc(func(context.Context, string, stt.Settings) error { return deliveryErr })
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventLoaded)
	run.send(stt.CommandStart)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	if err := await(t, run.done); !errors.Is(err, deliveryErr) {
		t.Fatalf("Run = %v", err)
	}
	want := []stt.EventType{stt.EventLoaded, stt.EventReady, stt.EventFinal, stt.EventError}
	if got := types(run.out.events(t)); !slices.Equal(got, want) {
		t.Fatalf("events = %v; want %v", got, want)
	}
	if begins, cancels := s.counts(); begins != 1 || cancels != 1 || r.notif.count() != 1 {
		t.Fatalf("Begin=%d Cancel=%d notifications=%d", begins, cancels, r.notif.count())
	}
}

func TestResidentResetsBeforeEachEnter(t *testing.T) {
	run, r, e := startResident(t)
	for cycle := 1; cycle <= 2; cycle++ {
		waitResidentEvent(t, run, stt.EventLoaded, cycle)
		run.send(stt.CommandStart)
		waitResidentEvent(t, run, stt.EventReady, cycle)
		r.submap.mu.Lock()
		calls := slices.Clone(r.submap.calls)
		r.submap.mu.Unlock()
		enters := 0
		for i, call := range calls {
			if call == "enter" {
				enters++
				if i == 0 || calls[i-1] != "reset" {
					t.Fatalf("Enter without preceding Reset: %v", calls)
				}
			}
		}
		if enters != cycle {
			t.Fatalf("Enter calls = %d; want %d", enters, cycle)
		}
		run.send(stt.CommandStop)
		waitResidentEvent(t, run, stt.EventLoaded, cycle+1)
	}
	finishResident(t, run, e, stt.CommandCancel, 2)
	assertResetWithLiveContext(t, r)
}

func TestMachineResidentCyclesClearPendingStop(t *testing.T) {
	m := NewMachine()
	steps := []struct {
		in   Input
		want State
	}{
		{InputPrepare, Preparing}, {InputLoaded, Standby},
		{InputStart, Starting}, {InputStop, Starting}, {InputReady, Stopping},
		{InputFinalized, Delivering}, {InputDelivered, Done}, {InputLoaded, Standby},
		{InputStart, Starting}, {InputReady, Listening}, {InputCancel, Cancelled},
		{InputLoaded, Standby}, {InputStart, Starting}, {InputReady, Listening},
	}
	for _, step := range steps {
		if got, err := m.Apply(step.in); err != nil || got != step.want {
			t.Fatalf("Apply(%s) = %s, %v; want %s", step.in, got, err, step.want)
		}
	}
}

func TestResidentShutdownDuringBegin(t *testing.T) {
	for _, cause := range []string{"signal", "eof"} {
		t.Run(cause, func(t *testing.T) {
			r := newRig(&fakeEngine{}, newStream("ignored"))
			r.deps.Standby = true
			entered := make(chan context.Context, 1)
			release := make(chan struct{})
			var once sync.Once
			unblock := func() { once.Do(func() { close(release) }) }
			defer unblock()
			cancelled := make(chan error, 1)
			s := &f002Standby{loaded: make(chan struct{}), stream: r.stream}
			close(s.loaded)
			r.deps.Engine = standbyEngineFunc(func(context.Context) (stt.Standby, error) {
				return lifecycleStandby{f002Standby: s,
					begin: func(ctx context.Context) (stt.Stream, error) {
						entered <- ctx
						<-release
						return r.stream, nil
					},
					cancel: func(ctx context.Context) error {
						select {
						case <-release:
						default:
							t.Error("Standby.Cancel ran concurrently with Begin")
						}
						cancelled <- ctx.Err()
						return nil
					}}, nil
			})
			run := start(t, context.Background(), r.deps)
			run.waitEvent(t, stt.EventLoaded)
			run.send(stt.CommandStart)
			beginCtx := await(t, entered)
			if cause == "signal" {
				run.cancel()
				await(t, beginCtx.Done())
			} else {
				run.stdin.Close()
			}
			unblock()
			assertCleanCancellation(t, run, r)
			if err := await(t, cancelled); err != nil {
				t.Fatalf("Standby.Cancel context = %v", err)
			}
			if _, n := r.stream.counts(); n != 1 {
				t.Fatalf("Stream.Cancel calls = %d", n)
			}
		})
	}
}
