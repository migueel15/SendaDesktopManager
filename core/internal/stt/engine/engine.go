// Package engine adapts the isolated Python recognizer and manages its runtime.
package engine

import (
	"context"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type engine struct{}

func New() stt.Engine { return &engine{} }
func (*engine) Start(context.Context, stt.EngineOptions) (stt.Stream, error) {
	return nil, stt.ErrNotImplemented
}
