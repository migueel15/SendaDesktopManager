package control

import (
	"context"
	"errors"
	"io"
	"reflect"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestDuckAudioRestoresSameSink(t *testing.T) {
	var calls [][]string
	run := stt.Runner(func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		if name != "wpctl" {
			t.Fatalf("unexpected command: %s", name)
		}
		calls = append(calls, append([]string{}, args...))
		switch args[0] {
		case "inspect":
			return []byte("id 149, type PipeWire:Interface:Node\n"), nil
		case "get-volume":
			return []byte("Volume: 0.73\n"), nil
		}
		return nil, nil
	})
	restore, err := DuckAudio(run, stt.LoadSettings(nil))(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if err := restore(context.Background()); err != nil {
		t.Fatal(err)
	}
	want := [][]string{{"inspect", "@DEFAULT_AUDIO_SINK@"}, {"get-volume", "149"}, {"set-volume", "149", "0.10"}, {"set-volume", "149", "0.73"}}
	if !reflect.DeepEqual(calls, want) {
		t.Fatalf("commands = %v", calls)
	}
}

func TestDuckAudioLeavesMutedOrQuieterOutput(t *testing.T) {
	// The default target is 10 %.
	for _, volume := range []string{"Volume: 0.73 [MUTED]", "Volume: 0.10", "Volume: 0.05", "Volume: 0.00"} {
		t.Run(volume, func(t *testing.T) {
			run := stt.Runner(func(_ context.Context, _ io.Reader, _ string, args ...string) ([]byte, error) {
				switch args[0] {
				case "inspect":
					return []byte("id 149, type node"), nil
				case "get-volume":
					return []byte(volume), nil
				}
				t.Fatalf("unexpected write: %v", args)
				return nil, nil
			})
			restore, err := DuckAudio(run, stt.LoadSettings(nil))(context.Background())
			if err != nil || restore != nil {
				t.Fatalf("restore=%v err=%v", restore != nil, err)
			}
		})
	}
}

func TestDuckAudioDoesNotWriteWithoutValidSnapshot(t *testing.T) {
	for _, volume := range []string{"invalid", "Volume: NaN", "Volume: -1"} {
		t.Run(volume, func(t *testing.T) {
			run := stt.Runner(func(_ context.Context, _ io.Reader, _ string, args ...string) ([]byte, error) {
				switch args[0] {
				case "inspect":
					return []byte("id 42, type node"), nil
				case "get-volume":
					return []byte(volume), nil
				default:
					t.Fatal("volume changed without a valid snapshot")
					return nil, nil
				}
			})
			if _, err := DuckAudio(run, stt.LoadSettings(nil))(context.Background()); err == nil {
				t.Fatal("expected snapshot error")
			}
		})
	}
}

func TestDuckAudioKeepsRestoreAfterFailedWrite(t *testing.T) {
	failed := false
	run := stt.Runner(func(_ context.Context, _ io.Reader, _ string, args ...string) ([]byte, error) {
		switch args[0] {
		case "inspect":
			return []byte("id 42, type node"), nil
		case "get-volume":
			return []byte("Volume: 0.65"), nil
		}
		if !failed {
			failed = true
			return nil, errors.New("write timeout")
		}
		if args[2] != "0.65" {
			t.Fatal("wrong restoration volume")
		}
		return nil, nil
	})
	restore, err := DuckAudio(run, stt.LoadSettings(nil))(context.Background())
	if err == nil || restore == nil {
		t.Fatal("failed write must retain cleanup")
	}
	if err := restore(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestDuckAudioDisabledDoesNotTouchAudio(t *testing.T) {
	settings := stt.LoadSettings(map[string]string{stt.KeyAudioDucking: "false"})
	run := stt.Runner(func(context.Context, io.Reader, string, ...string) ([]byte, error) {
		t.Fatal("audio command executed while disabled")
		return nil, nil
	})
	restore, err := DuckAudio(run, settings)(context.Background())
	if err != nil || restore != nil {
		t.Fatalf("disabled ducking returned cleanup or error: %v", err)
	}
}

func TestDuckAudioConfiguredPercentage(t *testing.T) {
	for _, percent := range []string{"0", "35", "100"} {
		t.Run(percent, func(t *testing.T) {
			settings := stt.LoadSettings(map[string]string{stt.KeyAudioVolume: percent})
			run := stt.Runner(func(_ context.Context, _ io.Reader, _ string, args ...string) ([]byte, error) {
				switch args[0] {
				case "inspect":
					return []byte("id 42, type node"), nil
				case "get-volume":
					return []byte("Volume: 0.73"), nil
				default:
					want := map[string]string{"0": "0.00", "35": "0.35", "100": "1.00"}[percent]
					if args[2] != want {
						t.Fatalf("volume=%s, want %s", args[2], want)
					}
					return nil, nil
				}
			})
			if _, err := DuckAudio(run, settings)(context.Background()); err != nil {
				t.Fatal(err)
			}
		})
	}
}
