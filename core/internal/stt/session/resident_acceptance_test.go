package session

import (
	"context"
	"fmt"
	"slices"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type residentStandby struct {
	mu      sync.Mutex
	loaded  chan struct{}
	streams []*residentStream
	begins  int
	cancels int
}

func (s *residentStandby) Loaded() <-chan struct{} {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.loaded
}
func (*residentStandby) Err() error { return nil }
func (s *residentStandby) Begin(ctx context.Context) (stt.Stream, error) {
	select {
	case <-s.Loaded():
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.begins >= len(s.streams) {
		return nil, fmt.Errorf("unexpected Begin %d", s.begins+1)
	}
	stream := s.streams[s.begins]
	s.begins++
	s.loaded = make(chan struct{})
	return stream, nil
}
func (s *residentStandby) Cancel(context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.cancels++
	return nil
}
func (s *residentStandby) counts() (int, int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.begins, s.cancels
}

type residentStream struct {
	*fakeStream
	standby *residentStandby
	once    sync.Once
}

func (s *residentStream) reloaded() {
	s.once.Do(func() {
		s.standby.mu.Lock()
		defer s.standby.mu.Unlock()
		close(s.standby.loaded)
	})
}
func (s *residentStream) Stop(ctx context.Context) (string, error) {
	text, err := s.fakeStream.Stop(ctx)
	s.reloaded()
	return text, err
}
func (s *residentStream) Cancel(ctx context.Context) error {
	err := s.fakeStream.Cancel(ctx)
	s.reloaded()
	return err
}

type residentEngine struct {
	standby          *residentStandby
	prepares, starts atomic.Int32
}

func (e *residentEngine) Prepare(context.Context, stt.EngineOptions) (stt.Standby, error) {
	e.prepares.Add(1)
	return e.standby, nil
}
func (e *residentEngine) Start(context.Context, stt.EngineOptions) (stt.Stream, error) {
	e.starts.Add(1)
	return nil, fmt.Errorf("resident session must use Begin")
}

func startResident(t *testing.T) (*running, *rig, *residentEngine) {
	t.Helper()
	s := &residentStandby{loaded: make(chan struct{})}
	close(s.loaded)
	for _, text := range []string{"primero", "segundo"} {
		s.streams = append(s.streams, &residentStream{fakeStream: newStream(text), standby: s})
	}
	e := &residentEngine{standby: s}
	r := newRig(&fakeEngine{}, s.streams[0].fakeStream)
	r.deps.Engine, r.deps.Standby = e, true
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	t.Cleanup(cancel)
	return start(t, ctx, r.deps), r, e
}

func waitResidentEvent(t *testing.T, run *running, typ stt.EventType, count int) {
	t.Helper()
	timer := time.NewTimer(time.Second)
	defer timer.Stop()
	for {
		n := 0
		for _, event := range run.out.events(t) {
			if event.Type == typ {
				n++
			}
		}
		if n >= count {
			return
		}
		select {
		case err := <-run.done:
			run.done <- err
			t.Fatalf("session ended before %s #%d: %v; events %v", typ, count, err, types(run.out.events(t)))
		case <-timer.C:
			t.Fatalf("missing %s #%d; events %v", typ, count, types(run.out.events(t)))
		case <-time.After(time.Millisecond):
		}
	}
}

func finishResident(t *testing.T, run *running, e *residentEngine, command string, begins int) {
	t.Helper()
	run.send(command)
	select {
	case err := <-run.done:
		if err != nil {
			t.Fatalf("idle %s: %v", command, err)
		}
	case <-time.After(time.Second):
		t.Fatal("idle shutdown did not finish")
	}
	gotBegins, cancels := e.standby.counts()
	if e.prepares.Load() != 1 || e.starts.Load() != 0 || gotBegins != begins || cancels != 1 {
		t.Fatalf("Prepare=%d Start=%d Begin=%d Standby.Cancel=%d", e.prepares.Load(), e.starts.Load(), gotBegins, cancels)
	}
	if has(run.out.events(t), stt.EventError) {
		t.Fatal("idle shutdown emitted error")
	}
}

func TestAC7F002ResidentTwoDictations(t *testing.T) {
	run, r, e := startResident(t)
	for cycle := 1; cycle <= 2; cycle++ {
		waitResidentEvent(t, run, stt.EventLoaded, cycle)
		run.send(stt.CommandStart)
		waitResidentEvent(t, run, stt.EventReady, cycle)
		run.send(stt.CommandStop)
		waitResidentEvent(t, run, stt.EventLoaded, cycle+1)
	}
	finishResident(t, run, e, stt.CommandCancel, 2)
	want := []stt.EventType{stt.EventLoaded, stt.EventReady, stt.EventFinal, stt.EventDelivered,
		stt.EventLoaded, stt.EventReady, stt.EventFinal, stt.EventDelivered, stt.EventLoaded, stt.EventCancelled}
	if got := types(run.out.events(t)); !slices.Equal(got, want) {
		t.Errorf("events = %v; want %v", got, want)
	}
	if got := r.deliv.delivered(); !slices.Equal(got, []string{"primero", "segundo"}) {
		t.Errorf("delivered = %v", got)
	}
}

func TestAC8F002ResidentCancelListeningThenDictate(t *testing.T) {
	run, r, e := startResident(t)
	waitResidentEvent(t, run, stt.EventLoaded, 1)
	run.send(stt.CommandStart)
	waitResidentEvent(t, run, stt.EventReady, 1)
	run.send(stt.CommandCancel)
	waitResidentEvent(t, run, stt.EventLoaded, 2)
	if got := r.deliv.delivered(); len(got) != 0 {
		t.Fatalf("cancel delivered %v", got)
	}
	if _, cancels := e.standby.streams[0].counts(); cancels != 1 {
		t.Fatalf("Stream.Cancel = %d", cancels)
	}
	run.send(stt.CommandStart)
	waitResidentEvent(t, run, stt.EventReady, 2)
	run.send(stt.CommandStop)
	waitResidentEvent(t, run, stt.EventLoaded, 3)
	finishResident(t, run, e, stt.CommandCancel, 2)
	want := []stt.EventType{stt.EventLoaded, stt.EventReady, stt.EventCancelled, stt.EventLoaded,
		stt.EventReady, stt.EventFinal, stt.EventDelivered, stt.EventLoaded, stt.EventCancelled}
	if got := types(run.out.events(t)); !slices.Equal(got, want) {
		t.Errorf("events = %v; want %v", got, want)
	}
	if got := r.deliv.delivered(); !slices.Equal(got, []string{"segundo"}) {
		t.Errorf("delivered = %v", got)
	}
}

func TestAC8F002ResidentIdleShutdown(t *testing.T) {
	for _, command := range []string{stt.CommandCancel, stt.CommandStop} {
		t.Run(command, func(t *testing.T) {
			run, r, e := startResident(t)
			waitResidentEvent(t, run, stt.EventLoaded, 1)
			finishResident(t, run, e, command, 0)
			if got := r.deliv.delivered(); len(got) != 0 {
				t.Fatalf("idle shutdown delivered %v", got)
			}
		})
	}
}

func TestAC8F002ResidentSignalAfterDictation(t *testing.T) {
	run, r, e := startResident(t)
	waitResidentEvent(t, run, stt.EventLoaded, 1)
	run.send(stt.CommandStart)
	waitResidentEvent(t, run, stt.EventReady, 1)
	run.send(stt.CommandStop)
	waitResidentEvent(t, run, stt.EventLoaded, 2)
	// Cancel the parent passed to Run, as the signal handler does.
	run.cancel()
	select {
	case err := <-run.done:
		if err != nil {
			t.Fatalf("signal in standby: %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("signal in standby did not terminate the session")
	}
	if has(run.out.events(t), stt.EventError) {
		t.Fatalf("signal emitted error: %v", run.out.events(t))
	}
	begins, cancels := e.standby.counts()
	if begins != 1 || cancels != 1 || e.prepares.Load() != 1 || e.starts.Load() != 0 {
		t.Errorf("Prepare=%d Start=%d Begin=%d Standby.Cancel=%d", e.prepares.Load(), e.starts.Load(), begins, cancels)
	}
	if got := r.deliv.delivered(); !slices.Equal(got, []string{"primero"}) {
		t.Errorf("delivered = %v", got)
	}
}
