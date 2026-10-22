package control

import (
	"context"
	"errors"
	"fmt"
	"math"
	"strconv"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// DuckAudio sets the current output to the configured percentage and returns a restoration action.
// Pin the node ID so a default-output change never modifies another device.
func DuckAudio(run stt.Runner, settings stt.Settings) func(context.Context) (func(context.Context) error, error) {
	if run == nil {
		run = stt.ExecRunner
	}
	return func(ctx context.Context) (func(context.Context) error, error) {
		if !settings.AudioDucking {
			return nil, nil
		}
		out, err := run(ctx, nil, "wpctl", "inspect", "@DEFAULT_AUDIO_SINK@")
		if err != nil {
			return nil, fmt.Errorf("no se pudo consultar la salida de audio: %w", err)
		}
		fields := strings.Fields(string(out))
		if len(fields) < 2 || fields[0] != "id" {
			return nil, errors.New("la salida de audio no tiene un identificador válido")
		}
		id := strings.TrimSuffix(fields[1], ",")
		if _, err := strconv.ParseUint(id, 10, 32); err != nil {
			return nil, errors.New("identificador de salida de audio no válido")
		}
		out, err = run(ctx, nil, "wpctl", "get-volume", id)
		if err != nil {
			return nil, fmt.Errorf("no se pudo leer el volumen: %w", err)
		}
		fields = strings.Fields(string(out))
		if len(fields) < 2 || fields[0] != "Volume:" {
			return nil, errors.New("respuesta de volumen no válida")
		}
		volume, err := strconv.ParseFloat(fields[1], 64)
		if err != nil || math.IsNaN(volume) || math.IsInf(volume, 0) || volume < 0 {
			return nil, errors.New("volumen de salida no válido")
		}
		previous := strconv.FormatFloat(volume, 'f', -1, 64)
		restore := func(ctx context.Context) error {
			_, err := run(ctx, nil, "wpctl", "set-volume", id, previous)
			if err != nil {
				return fmt.Errorf("no se pudo restaurar el volumen: %w", err)
			}
			return nil
		}
		// Return restore even on a failed write: the command may have applied it
		// before its context expired. The session always runs this cleanup.
		_, err = run(ctx, nil, "wpctl", "set-volume", id, strconv.FormatFloat(float64(settings.AudioVolume)/100, 'f', 2, 64))
		if err != nil {
			return restore, fmt.Errorf("no se pudo bajar el volumen del dictado: %w", err)
		}
		return restore, nil
	}
}
