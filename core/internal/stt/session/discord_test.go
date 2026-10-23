package session

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestDictationRestoresDiscordMuteOnExit(t *testing.T) {
	for _, action := range []string{"stop", "cancel", "signal", "engine-error"} {
		t.Run(action, func(t *testing.T) {
			engine := &fakeEngine{}
			if action == "engine-error" {
				engine.err = errors.New("engine failed")
			}
			r := newRig(engine, newStream("hola"))
			var muted, restored atomic.Int32
			r.deps.MuteDiscord = func(context.Context) func(context.Context) error {
				muted.Add(1)
				return func(ctx context.Context) error {
					if ctx.Err() != nil {
						t.Error("restoration used cancelled context")
					}
					restored.Add(1)
					return nil
				}
			}
			run := start(t, context.Background(), r.deps)
			if action != "engine-error" {
				run.waitEvent(t, stt.EventReady)
				if muted.Load() != 1 || restored.Load() != 0 {
					t.Fatal("Discord not muted while listening")
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
			if muted.Load() != 1 || restored.Load() != 1 {
				t.Fatalf("muted=%d restored=%d", muted.Load(), restored.Load())
			}
		})
	}
}

func TestDiscordRestoreFailureDoesNotEndDictation(t *testing.T) {
	r := newRig(&fakeEngine{}, newStream("hola"))
	r.deps.MuteDiscord = func(context.Context) func(context.Context) error {
		return func(context.Context) error { return errors.New("bridge gone") }
	}
	run := start(t, context.Background(), r.deps)
	run.waitEvent(t, stt.EventReady)
	run.send("stop")
	select {
	case err := <-run.done:
		if err != nil {
			t.Fatalf("Discord failure ended the dictation: %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("session did not exit")
	}
}
