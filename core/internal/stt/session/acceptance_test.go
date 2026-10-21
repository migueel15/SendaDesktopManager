package session

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"slices"
	"sync"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type fakeStream struct {
	mu      sync.Mutex
	results chan stt.Result
	err     error
	text    string
	closed  bool
	stops   int
	cancels int
}

func newStream(text string) *fakeStream {
	return &fakeStream{results: make(chan stt.Result, 8), text: text}
}

func (s *fakeStream) Results() <-chan stt.Result { return s.results }
func (s *fakeStream) Err() error                 { s.mu.Lock(); defer s.mu.Unlock(); return s.err }
func (s *fakeStream) close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.closed {
		s.closed = true
		close(s.results)
	}
}
func (s *fakeStream) fail(err error) {
	s.mu.Lock()
	s.err = err
	s.mu.Unlock()
	s.close()
}
func (s *fakeStream) Stop(context.Context) (string, error) {
	s.mu.Lock()
	s.stops++
	s.mu.Unlock()
	s.close()
	return s.text, nil
}
func (s *fakeStream) Cancel(context.Context) error {
	s.mu.Lock()
	s.cancels++
	s.mu.Unlock()
	s.close()
	return nil
}
func (s *fakeStream) counts() (int, int) { s.mu.Lock(); defer s.mu.Unlock(); return s.stops, s.cancels }

type fakeEngine struct {
	stream  *fakeStream
	err     error
	release chan struct{} // when set, Start blocks until closed
}

func (e *fakeEngine) Start(ctx context.Context, _ stt.EngineOptions) (stt.Stream, error) {
	if e.release != nil {
		select {
		case <-e.release:
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	if e.err != nil {
		return nil, e.err
	}
	return e.stream, nil
}

type fakeDeliverer struct {
	mu    sync.Mutex
	texts []string
}

func (d *fakeDeliverer) Deliver(_ context.Context, text string, _ stt.Settings) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.texts = append(d.texts, text)
	return nil
}
func (d *fakeDeliverer) delivered() []string {
	d.mu.Lock()
	defer d.mu.Unlock()
	return slices.Clone(d.texts)
}

type fakeSubmap struct {
	mu         sync.Mutex
	enterErr   error
	enters     int
	resets     int
	resetCtxOK []bool
}

func (m *fakeSubmap) Enter(context.Context) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.enters++
	return m.enterErr
}
func (m *fakeSubmap) Reset(ctx context.Context) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.resets++
	m.resetCtxOK = append(m.resetCtxOK, ctx.Err() == nil)
	return nil
}
func (m *fakeSubmap) counts() (int, int) { m.mu.Lock(); defer m.mu.Unlock(); return m.enters, m.resets }

type fakeNotifier struct {
	mu    sync.Mutex
	calls int
}

func (n *fakeNotifier) Notify(context.Context, string, string) error {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.calls++
	return nil
}
func (n *fakeNotifier) count() int { n.mu.Lock(); defer n.mu.Unlock(); return n.calls }

type rig struct {
	deps   Deps
	stream *fakeStream
	deliv  *fakeDeliverer
	submap *fakeSubmap
	notif  *fakeNotifier
}

func newRig(engine *fakeEngine, stream *fakeStream) *rig {
	r := &rig{stream: stream, deliv: &fakeDeliverer{}, submap: &fakeSubmap{}, notif: &fakeNotifier{}}
	engine.stream = stream
	r.deps = Deps{Engine: engine, Deliverer: r.deliv, Submap: r.submap, Notifier: r.notif,
		Settings: stt.LoadSettings(nil), ModelDir: "/model", CleanupTimeout: time.Second}
	return r
}

// syncBuffer is a goroutine-safe stdout.
type syncBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *syncBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}
func (b *syncBuffer) events(t *testing.T) []stt.Event {
	t.Helper()
	b.mu.Lock()
	defer b.mu.Unlock()
	var events []stt.Event
	sc := bufio.NewScanner(bytes.NewReader(b.buf.Bytes()))
	for sc.Scan() {
		var e stt.Event
		if err := json.Unmarshal(sc.Bytes(), &e); err != nil {
			t.Fatalf("invalid event line %q: %v", sc.Text(), err)
		}
		events = append(events, e)
	}
	return events
}

func types(events []stt.Event) []stt.EventType {
	var out []stt.EventType
	for _, e := range events {
		out = append(out, e.Type)
	}
	return out
}

func has(events []stt.Event, typ stt.EventType) bool {
	return slices.Contains(types(events), typ)
}

// bufPipe is an in-memory pipe whose Write never blocks, so tests can send
// commands even when the session is not reading stdin.
type bufPipe struct {
	mu     sync.Mutex
	cond   *sync.Cond
	data   []byte
	closed bool
}

func newBufPipe() *bufPipe {
	p := &bufPipe{}
	p.cond = sync.NewCond(&p.mu)
	return p
}

func (p *bufPipe) Write(b []byte) (int, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.data = append(p.data, b...)
	p.cond.Broadcast()
	return len(b), nil
}

func (p *bufPipe) Read(b []byte) (int, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	for len(p.data) == 0 && !p.closed {
		p.cond.Wait()
	}
	if len(p.data) == 0 {
		return 0, io.EOF
	}
	n := copy(b, p.data)
	p.data = p.data[n:]
	return n, nil
}

func (p *bufPipe) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.closed = true
	p.cond.Broadcast()
	return nil
}

// start runs the session in the background and returns a handle.
type running struct {
	stdin  *bufPipe
	out    *syncBuffer
	done   chan error
	cancel context.CancelFunc
}

func start(t *testing.T, ctx context.Context, deps Deps) *running {
	t.Helper()
	ctx, cancel := context.WithCancel(ctx)
	pw := newBufPipe()
	pr := pw
	r := &running{stdin: pw, out: &syncBuffer{}, done: make(chan error, 1), cancel: cancel}
	go func() { r.done <- Run(ctx, deps, pr, r.out) }()
	t.Cleanup(func() { cancel(); pw.Close() })
	return r
}

func (r *running) send(cmd string) { io.WriteString(r.stdin, cmd+"\n") }

func (r *running) wait(t *testing.T) {
	t.Helper()
	select {
	case err := <-r.done:
		if errors.Is(err, stt.ErrNotImplemented) {
			t.Fatalf("Run: %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("Run did not return")
	}
}

func (r *running) waitEvent(t *testing.T, typ stt.EventType) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if has(r.out.events(t), typ) {
			return
		}
		select {
		case err := <-r.done:
			r.done <- err
			if errors.Is(err, stt.ErrNotImplemented) {
				t.Fatalf("Run: %v", err)
			}
		case <-time.After(5 * time.Millisecond):
		}
	}
	t.Fatalf("event %q not seen: %v", typ, types(r.out.events(t)))
}

func (r *running) waitPartialCount(t *testing.T, n int) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		count := 0
		for _, e := range r.out.events(t) {
			if e.Type == stt.EventPartial {
				count++
			}
		}
		if count >= n {
			return
		}
		select {
		case err := <-r.done:
			r.done <- err
			if errors.Is(err, stt.ErrNotImplemented) {
				t.Fatalf("Run: %v", err)
			}
		case <-time.After(5 * time.Millisecond):
		}
	}
	t.Fatalf("fewer than %d partial events: %v", n, types(r.out.events(t)))
}

func TestAC1StopDeliversFinalText(t *testing.T) {
	stream := newStream("hola mundo")
	r := newRig(&fakeEngine{}, stream)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	stream.results <- stt.Result{Text: "hola"}
	run.waitEvent(t, stt.EventPartial)
	stream.results <- stt.Result{Text: "hola mundo"}
	run.waitPartialCount(t, 2)
	run.send(stt.CommandStop)
	run.wait(t)

	events := run.out.events(t)
	if got := types(events); got[0] != stt.EventReady {
		t.Fatalf("first event = %v", got)
	}
	var partials []string
	var final, delivered = -1, -1
	for i, e := range events {
		switch e.Type {
		case stt.EventPartial:
			partials = append(partials, e.Text)
		case stt.EventFinal:
			final = i
			if e.Text != "hola mundo" {
				t.Errorf("final text = %q", e.Text)
			}
		case stt.EventDelivered:
			delivered = i
		}
	}
	if len(partials) < 2 || partials[0] != "hola" || partials[len(partials)-1] != "hola mundo" {
		t.Errorf("partials = %v", partials)
	}
	if final < 0 || delivered < final {
		t.Errorf("event order wrong: %v", types(events))
	}
	if got := r.deliv.delivered(); !slices.Equal(got, []string{"hola mundo"}) {
		t.Errorf("delivered = %v", got)
	}
	if enters, resets := r.submap.counts(); enters != 1 || resets < 1 {
		t.Errorf("submap enters=%d resets=%d", enters, resets)
	}
}

func TestAC1MachineHappyPath(t *testing.T) {
	m := NewMachine()
	if m.State() != Idle {
		t.Fatalf("initial state = %s", m.State())
	}
	steps := []struct {
		in   Input
		want State
	}{
		{InputStart, Starting}, {InputReady, Listening}, {InputStop, Stopping},
		{InputFinalized, Delivering}, {InputDelivered, Done},
	}
	for _, s := range steps {
		got, err := m.Apply(s.in)
		if err != nil || got != s.want || m.State() != s.want {
			t.Fatalf("Apply(%s) = %s, %v; want %s", s.in, got, err, s.want)
		}
	}
}

func TestAC1MachineRejectsInvalidTransitions(t *testing.T) {
	m := NewMachine()
	for _, in := range []Input{InputStop, InputReady, InputFinalized, InputDelivered} {
		if _, err := m.Apply(in); err == nil || errors.Is(err, stt.ErrNotImplemented) {
			t.Errorf("Apply(%s) from idle = %v, want a transition error", in, err)
		}
		if m.State() != Idle {
			t.Fatalf("state changed to %s", m.State())
		}
	}
	m.Apply(InputStart)
	m.Apply(InputReady)
	if _, err := m.Apply(InputDelivered); err == nil {
		t.Error("listening → delivered accepted")
	}
}

func assertNoDelivery(t *testing.T, r *rig) {
	t.Helper()
	if got := r.deliv.delivered(); len(got) != 0 {
		t.Errorf("delivered %v", got)
	}
}

func assertResetWithLiveContext(t *testing.T, r *rig) {
	t.Helper()
	_, resets := r.submap.counts()
	if resets < 1 {
		t.Fatal("Reset not called")
	}
	for _, ok := range r.submap.resetCtxOK {
		if !ok {
			t.Error("Reset received a cancelled context")
		}
	}
}

func TestAC2CancelCommand(t *testing.T) {
	stream := newStream("ignored")
	r := newRig(&fakeEngine{}, stream)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandCancel)
	run.wait(t)
	assertNoDelivery(t, r)
	if _, cancels := stream.counts(); cancels < 1 {
		t.Error("Stream.Cancel not called")
	}
	if !has(run.out.events(t), stt.EventCancelled) {
		t.Errorf("events = %v", types(run.out.events(t)))
	}
	assertResetWithLiveContext(t, r)
}

func TestAC2ContextCancelled(t *testing.T) {
	stream := newStream("ignored")
	r := newRig(&fakeEngine{}, stream)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.cancel()
	run.wait(t)
	assertNoDelivery(t, r)
	if _, cancels := stream.counts(); cancels < 1 {
		t.Error("Stream.Cancel not called")
	}
	if !has(run.out.events(t), stt.EventCancelled) {
		t.Errorf("events = %v", types(run.out.events(t)))
	}
	assertResetWithLiveContext(t, r)
}

func TestAC2StdinEOF(t *testing.T) {
	stream := newStream("ignored")
	r := newRig(&fakeEngine{}, stream)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.stdin.Close()
	run.wait(t)
	assertNoDelivery(t, r)
	if _, cancels := stream.counts(); cancels < 1 {
		t.Error("Stream.Cancel not called")
	}
	if !has(run.out.events(t), stt.EventCancelled) {
		t.Errorf("events = %v", types(run.out.events(t)))
	}
	assertResetWithLiveContext(t, r)
}

func TestAC2EngineStartFailure(t *testing.T) {
	r := newRig(&fakeEngine{err: errors.New("sin motor")}, newStream(""))
	run := start(t, context.Background(), r.deps)
	run.wait(t)
	assertNoDelivery(t, r)
	if !has(run.out.events(t), stt.EventError) {
		t.Errorf("events = %v", types(run.out.events(t)))
	}
	if n := r.notif.count(); n != 1 {
		t.Errorf("Notify calls = %d", n)
	}
	assertResetWithLiveContext(t, r)
}

func TestAC2AsyncStreamFailure(t *testing.T) {
	stream := newStream("ignored")
	r := newRig(&fakeEngine{}, stream)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	stream.fail(errors.New("micrófono desconectado"))
	run.wait(t)
	assertNoDelivery(t, r)
	if !has(run.out.events(t), stt.EventError) {
		t.Errorf("events = %v", types(run.out.events(t)))
	}
	if n := r.notif.count(); n != 1 {
		t.Errorf("Notify calls = %d", n)
	}
	assertResetWithLiveContext(t, r)
}

func TestAC2StopBeforeReady(t *testing.T) {
	stream := newStream("texto")
	engine := &fakeEngine{release: make(chan struct{})}
	r := newRig(engine, stream)
	run := start(t, context.Background(), r.deps)
	run.send(stt.CommandStop)
	time.Sleep(50 * time.Millisecond)
	close(engine.release)
	run.wait(t)
	if got := r.deliv.delivered(); !slices.Equal(got, []string{"texto"}) {
		t.Errorf("delivered = %v", got)
	}
}

func TestAC2DoubleStopDeliversOnce(t *testing.T) {
	stream := newStream("texto")
	r := newRig(&fakeEngine{}, stream)
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	run.send(stt.CommandStop)
	run.wait(t)
	if got := r.deliv.delivered(); len(got) != 1 {
		t.Errorf("delivered = %v", got)
	}
}

func TestAC2SubmapUnavailableDoesNotBlockSession(t *testing.T) {
	stream := newStream("texto")
	r := newRig(&fakeEngine{}, stream)
	r.submap.enterErr = stt.ErrSubmapUnavailable
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	run.wait(t)
	if got := r.deliv.delivered(); !slices.Equal(got, []string{"texto"}) {
		t.Errorf("delivered = %v", got)
	}
}
