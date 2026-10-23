package control

import (
	"context"
	"errors"
	"io"
	"reflect"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// fakeDiscord answers `senda discord status` with states in order, and records every call.
type fakeDiscord struct {
	states []string
	fail   string
	calls  []string
}

func (f *fakeDiscord) runner() stt.Runner {
	return func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		if name != "senda" || len(args) != 2 || args[0] != "discord" {
			return nil, errors.New("unexpected command")
		}
		f.calls = append(f.calls, args[1])
		if args[1] == f.fail {
			return nil, errors.New("bridge error")
		}
		if args[1] == "status" {
			state := f.states[0]
			if len(f.states) > 1 {
				f.states = f.states[1:]
			}
			return []byte(state), nil
		}
		return nil, nil
	}
}

const (
	openMic     = `{"authenticated": true, "mute": false, "deaf": false}`
	mutedMic    = `{"authenticated": true, "mute": true, "deaf": false}`
	deafenedMic = `{"authenticated": true, "mute": true, "deaf": true}`
)

func TestMuteDiscordMutesOpenMicAndRestoresIt(t *testing.T) {
	f := &fakeDiscord{states: []string{openMic, mutedMic}}
	restore := MuteDiscord(f.runner(), "senda")(context.Background())
	if restore == nil {
		t.Fatal("expected a restoration for an open microphone")
	}
	if err := restore(context.Background()); err != nil {
		t.Fatal(err)
	}
	want := []string{"status", "mute", "status", "unmute"}
	if !reflect.DeepEqual(f.calls, want) {
		t.Fatalf("calls = %v, want %v", f.calls, want)
	}
}

func TestMuteDiscordLeavesMicAsFoundWhenMutedOrDeafened(t *testing.T) {
	for _, state := range []string{mutedMic, deafenedMic} {
		f := &fakeDiscord{states: []string{state}}
		if restore := MuteDiscord(f.runner(), "senda")(context.Background()); restore != nil {
			t.Fatalf("state %s: expected no restoration", state)
		}
		if want := []string{"status"}; !reflect.DeepEqual(f.calls, want) {
			t.Fatalf("state %s: calls = %v, want %v", state, f.calls, want)
		}
	}
}

func TestMuteDiscordDoesNothingWithoutAuthorizationOrBridge(t *testing.T) {
	for _, state := range []string{`{"authenticated": false, "mute": false, "deaf": false}`, `not json`} {
		f := &fakeDiscord{states: []string{state}}
		if restore := MuteDiscord(f.runner(), "senda")(context.Background()); restore != nil {
			t.Fatalf("state %s: expected no restoration", state)
		}
		if want := []string{"status"}; !reflect.DeepEqual(f.calls, want) {
			t.Fatalf("state %s: calls = %v, want %v", state, f.calls, want)
		}
	}
	f := &fakeDiscord{fail: "status"}
	if restore := MuteDiscord(f.runner(), "senda")(context.Background()); restore != nil {
		t.Fatal("expected no restoration when status fails")
	}
}

func TestMuteDiscordDoesNotUnmuteWhenDeafenedDuringDictation(t *testing.T) {
	f := &fakeDiscord{states: []string{openMic, deafenedMic}}
	restore := MuteDiscord(f.runner(), "senda")(context.Background())
	if err := restore(context.Background()); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(strings.Join(f.calls, " "), "unmute") {
		t.Fatalf("unmute would also undeafen: calls = %v", f.calls)
	}
}

func TestMuteDiscordDoesNotUnmuteWhenUserUnmutedDuringDictation(t *testing.T) {
	f := &fakeDiscord{states: []string{openMic, openMic}}
	restore := MuteDiscord(f.runner(), "senda")(context.Background())
	if err := restore(context.Background()); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(strings.Join(f.calls, " "), "unmute") {
		t.Fatalf("microphone was reopened by the user: calls = %v", f.calls)
	}
}

func TestMuteDiscordReportsFailedMuteWithoutUnmuting(t *testing.T) {
	f := &fakeDiscord{states: []string{openMic}, fail: "mute"}
	restore := MuteDiscord(f.runner(), "senda")(context.Background())
	if restore == nil {
		t.Fatal("expected the failure to be reported")
	}
	if err := restore(context.Background()); err == nil {
		t.Fatal("expected the mute failure to be reported")
	}
	if strings.Contains(strings.Join(f.calls, " "), "unmute") {
		t.Fatalf("unmute after a failed mute: calls = %v", f.calls)
	}
}

func TestMuteDiscordNeverDeafens(t *testing.T) {
	f := &fakeDiscord{states: []string{openMic, mutedMic}}
	restore := MuteDiscord(f.runner(), "senda")(context.Background())
	_ = restore(context.Background())
	for _, call := range f.calls {
		if strings.Contains(call, "deaf") {
			t.Fatalf("deafen action called: %v", f.calls)
		}
	}
}
