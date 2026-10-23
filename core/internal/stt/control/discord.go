package control

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// discordCallTimeout bounds each `senda discord` call so a stalled bridge never holds up dictation.
const discordCallTimeout = time.Second

// discordState is the part of `senda discord status` the dictation session reads.
type discordState struct {
	Authenticated bool `json:"authenticated"`
	Mute          bool `json:"mute"`
	Deaf          bool `json:"deaf"`
}

// MuteDiscord mutes the Discord microphone when it is open at the start of a dictation.
// It returns the restoration only when Senda muted the microphone, so the cleanup
// never reopens a microphone the user had closed. It never changes deafen, and an
// unavailable bridge leaves the dictation running without muting. command is the
// senda executable, which runs its own `discord` subcommands.
func MuteDiscord(run stt.Runner, command string) func(context.Context) func(context.Context) error {
	if run == nil {
		run = stt.ExecRunner
	}
	return func(ctx context.Context) func(context.Context) error {
		state, err := discordStatus(ctx, run, command)
		if err != nil || !state.Authenticated || state.Mute || state.Deaf {
			return nil
		}
		if _, err := runDiscord(ctx, run, command, "mute"); err != nil {
			return func(context.Context) error {
				return fmt.Errorf("no se pudo silenciar el micro de Discord: %w", err)
			}
		}
		return func(ctx context.Context) error {
			state, err := discordStatus(ctx, run, command)
			if err != nil {
				return fmt.Errorf("no se pudo comprobar el micro de Discord: %w", err)
			}
			if !state.Authenticated {
				return errors.New("Discord ya no está autorizado; el micro sigue silenciado")
			}
			// The user changed the microphone during dictation; unmute would also undeafen.
			if !state.Mute || state.Deaf {
				return nil
			}
			if _, err := runDiscord(ctx, run, command, "unmute"); err != nil {
				return fmt.Errorf("no se pudo desmutear el micro de Discord: %w", err)
			}
			return nil
		}
	}
}

func discordStatus(ctx context.Context, run stt.Runner, command string) (discordState, error) {
	out, err := runDiscord(ctx, run, command, "status")
	if err != nil {
		return discordState{}, err
	}
	var state discordState
	if err := json.Unmarshal(out, &state); err != nil {
		return discordState{}, fmt.Errorf("estado de Discord no válido: %w", err)
	}
	return state, nil
}

func runDiscord(ctx context.Context, run stt.Runner, command string, action string) ([]byte, error) {
	callCtx, done := context.WithTimeout(ctx, discordCallTimeout)
	defer done()
	return run(callCtx, nil, command, "discord", action)
}
