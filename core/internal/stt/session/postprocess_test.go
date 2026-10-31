package session

import (
	"context"
	"errors"
	"slices"
	"sync/atomic"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestFinalPostprocessing(t *testing.T) {
	for _, mode := range []string{"enabled", "disabled", "failure", "panic", "empty"} {
		t.Run(mode, func(t *testing.T) {
			r := newRig(&fakeEngine{}, newStream("hola"))
			r.deps.Settings.Postprocess = mode != "disabled"
			var calls atomic.Int32
			r.deps.Postprocess = func(ctx context.Context, text string) (string, error) {
				calls.Add(1)
				if text != "hola" {
					t.Error(text)
				}
				if _, ok := ctx.Deadline(); !ok {
					t.Error("unbounded postprocess")
				}
				switch mode {
				case "failure":
					return "", errors.New("model unavailable")
				case "panic":
					panic("model panic")
				case "empty":
					return "", nil
				}
				return "Hola.", nil
			}
			run := start(t, context.Background(), r.deps)
			run.waitEvent(t, stt.EventReady)
			r.stream.results <- stt.Result{Text: "parcial"}
			run.waitEvent(t, stt.EventPartial)
			if calls.Load() != 0 {
				t.Fatal("processed partial")
			}
			run.send(stt.CommandStop)
			run.wait(t)
			want := "hola"
			if mode == "enabled" {
				want = "Hola."
			}
			if !slices.Equal(r.deliv.delivered(), []string{want}) {
				t.Fatal(r.deliv.delivered())
			}
			for _, e := range run.out.events(t) {
				if e.Type == stt.EventFinal && (e.Text != want || e.OriginalText != "hola") {
					t.Fatal(e)
				}
			}
			if mode != "disabled" && calls.Load() != 1 {
				t.Fatal("not exactly once")
			}
		})
	}
}

func TestCancelDuringPostprocessing(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream("hola"))
	r.deps.Settings.Postprocess = true
	entered, stopped := make(chan struct{}), make(chan struct{})
	r.deps.Postprocess = func(ctx context.Context, _ string) (string, error) {
		close(entered)
		<-ctx.Done()
		close(stopped)
		return "Hola.", nil
	}
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	<-entered
	run.send(stt.CommandCancel)
	run.wait(t)
	<-stopped
	assertNoDelivery(t, r)
}

func TestPostprocessingDeadlineDeliversOriginal(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream("hola"))
	r.deps.Settings.Postprocess = true
	// Even a broken adapter ignoring cancellation cannot block delivery.
	release := make(chan struct{})
	defer close(release)
	r.deps.Postprocess = func(context.Context, string) (string, error) { <-release; return "Hola.", nil }
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send(stt.CommandStop)
	select {
	case err := <-run.done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(10 * time.Second):
		t.Fatal("postprocess blocked delivery")
	}
	if !slices.Equal(r.deliv.delivered(), []string{"hola"}) {
		t.Fatal(r.deliv.delivered())
	}
}
