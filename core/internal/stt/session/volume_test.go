package session

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestDictationRestoresVolumeOnExit(t *testing.T) {
	for _, action := range []string{"stop", "cancel", "signal", "engine-error"} {
		t.Run(action, func(t *testing.T) {
			engine := &fakeEngine{}
			if action == "engine-error" {
				engine.err = errors.New("engine failed")
			}
			r := newRig(engine, newStream("hola"))
			var ducked, restored atomic.Int32
			r.deps.DuckAudio = func(context.Context) (func(context.Context) error, error) {
				ducked.Add(1)
				return func(ctx context.Context) error {
					if ctx.Err() != nil {
						t.Error("restoration used cancelled context")
					}
					restored.Add(1)
					return nil
				}, nil
			}
			run := start(t, context.Background(), r.deps)
			if action != "engine-error" {
				run.waitEvent(t, stt.EventReady)
				if ducked.Load() != 1 || restored.Load() != 0 {
					t.Fatal("volume not ducked while listening")
				}
				if action == "signal" {
					run.cancel()
				} else {
					run.send(action)
				}
			}
			select {
			case err := <-run.done:
				if action == "engine-error" && err == nil {
					t.Fatal("expected engine failure")
				}
				if action != "engine-error" && err != nil {
					t.Fatal(err)
				}
			case <-time.After(3 * time.Second):
				t.Fatal("session did not exit")
			}
			if ducked.Load() != 1 || restored.Load() != 1 {
				t.Fatalf("ducked=%d restored=%d", ducked.Load(), restored.Load())
			}
		})
	}
}
