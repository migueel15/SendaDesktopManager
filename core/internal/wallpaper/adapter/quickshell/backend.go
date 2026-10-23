package quickshell

import (
	"encoding/json"
	"errors"

	"github.com/migueel15/SendaDesktopManager/core/internal/wallpaper"
)

type Call func(target, function string, args ...string) (string, error)

type Backend struct{ call Call }

var _ wallpaper.Backend = (*Backend)(nil)

func NewBackend(call Call) *Backend { return &Backend{call: call} }

func (b *Backend) Set(w wallpaper.Wallpaper, options wallpaper.SetOptions) error {
	payload := struct {
		Path       string               `json:"path"`
		Monitor    string               `json:"monitor"`
		Resize     wallpaper.ResizeMode `json:"resize"`
		Transition struct {
			Type       wallpaper.AnimationKind `json:"type"`
			DurationMs int64                   `json:"durationMs"`
			Pos        *wallpaper.Position     `json:"pos"`
			Bezier     [4]float64              `json:"bezier"`
		} `json:"transition"`
	}{Path: w.Path, Resize: wallpaper.ResizeCrop}
	payload.Transition.Type = wallpaper.AnimationNone
	payload.Transition.DurationMs = 3000
	payload.Transition.Bezier = [4]float64{.61, .18, .48, .9}
	if options.Monitor != nil {
		payload.Monitor = string(*options.Monitor)
	}
	if options.Resize != nil {
		payload.Resize = *options.Resize
	}
	if a := options.Animation; a != nil {
		payload.Transition.Type = a.Kind
		payload.Transition.DurationMs = a.Duration.Milliseconds()
		payload.Transition.Pos = a.Origin
		payload.Transition.Bezier = a.Bezier
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	result, err := b.call("wallpaper", "set", string(data))
	if err != nil {
		return err
	}
	if result != "" {
		return errors.New(result)
	}
	return nil
}
