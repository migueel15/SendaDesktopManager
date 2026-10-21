// Package binds manages Senda's Hyprland Lua shortcuts and dictation submap.
package binds

import (
	"context"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

const (
	ModuleName = "senda_binds"
	SubmapName = "senda_stt"
)

// Path will resolve $XDG_CONFIG_HOME/hypr/modules/senda_binds.lua, falling back
// to ~/.config. Non-error-returning stubs return zero values until implemented.
func Path() string                                     { return "" }
func RequireLine() string                              { return "" }
func NormalizeShortcut(string) (string, error)         { return "", stt.ErrNotImplemented }
func Render(string, string) ([]byte, error)            { return nil, stt.ErrNotImplemented }
func Write(string, []byte) error                       { return stt.ErrNotImplemented }
func Reload(context.Context, stt.Runner) error         { return stt.ErrNotImplemented }
func Loaded(context.Context, stt.Runner) (bool, error) { return false, stt.ErrNotImplemented }
func Conflicts(context.Context, stt.Runner, string) ([]string, error) {
	return nil, stt.ErrNotImplemented
}
func EnsureDefault(string, string) (bool, error) { return false, stt.ErrNotImplemented }
func RenderDisabled() []byte                     { return nil }

type submap struct{ run stt.Runner }

func NewSubmap(run stt.Runner) stt.Submap   { return &submap{run: run} }
func (*submap) Enter(context.Context) error { return stt.ErrNotImplemented }
func (*submap) Reset(context.Context) error { return stt.ErrNotImplemented }
