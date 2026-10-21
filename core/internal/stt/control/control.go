// Package control provides preflight checks, shell IPC control and notifications.
//
// Shell IPC target "stt" exposes toggle(): string, cancel(): bool, and
// status(): string ("idle" or the current session state).
package control

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type Checks struct {
	ModelInstalled   func(id string) bool
	RuntimeInstalled func() bool
	Microphone       func(ctx context.Context) error
}

var ErrNoModel = errors.New("No hay ningún modelo de dictado instalado. Instálalo en Ajustes → Dictado o con senda stt models install <id>.")
var ErrNoRuntime = errors.New("El motor de dictado no está instalado. Instálalo con senda stt runtime install.")
var ErrNoMicrophone = errors.New("No hay ningún micrófono disponible. Conecta uno y comprueba la entrada de audio.")

func Preflight(ctx context.Context, settings stt.Settings, checks Checks) error {
	if checks.ModelInstalled == nil || !checks.ModelInstalled(settings.ModelID) {
		return ErrNoModel
	}
	if checks.RuntimeInstalled == nil || !checks.RuntimeInstalled() {
		return ErrNoRuntime
	}
	if checks.Microphone == nil {
		return ErrNoMicrophone
	}
	if err := checks.Microphone(ctx); err != nil {
		return fmt.Errorf("%w: %v", ErrNoMicrophone, err)
	}
	return nil
}

// CheckMicrophone queries the default source and rejects output monitors.
func CheckMicrophone(ctx context.Context, run stt.Runner) error {
	if run == nil {
		run = stt.ExecRunner
	}
	if out, err := run(ctx, nil, "wpctl", "inspect", "@DEFAULT_AUDIO_SOURCE@"); err == nil {
		data := string(out)
		if strings.Contains(data, "media.class = \"Audio/Source\"") && !strings.Contains(strings.ToLower(data), ".monitor") {
			return nil
		}
	}
	out, err := run(ctx, nil, "pactl", "get-default-source")
	if err != nil {
		return fmt.Errorf("no se pudo consultar la fuente de audio: %w", err)
	}
	source := strings.TrimSpace(string(out))
	if source == "" || strings.HasSuffix(strings.ToLower(source), ".monitor") {
		return errors.New("la fuente predeterminada no es un micrófono")
	}
	return nil
}

// Shell.Call invokes function on IPC target "stt".
type Shell interface {
	Call(ctx context.Context, function string) (string, error)
}

// Toggle runs preflight before starting dictation, including from preload states.
func Toggle(ctx context.Context, shell Shell, preflight func() error) (string, error) {
	status, err := Status(ctx, shell)
	if err != nil {
		return "", err
	}
	if status == "idle" || status == "preparing" || status == "standby" {
		if err := preflight(); err != nil {
			return "", err
		}
	}
	return shell.Call(ctx, "toggle")
}

func Status(ctx context.Context, shell Shell) (string, error) {
	result, err := shell.Call(ctx, "status")
	if err != nil {
		return "", err
	}
	result = strings.TrimSpace(result)
	if strings.HasPrefix(result, "\"") {
		if decoded, decodeErr := strconv.Unquote(result); decodeErr == nil {
			result = decoded
		}
	}
	if result == "" {
		return "", errors.New("la shell no devolvió el estado del dictado")
	}
	return result, nil
}

func Cancel(ctx context.Context, shell Shell) error {
	_, err := shell.Call(ctx, "cancel")
	return err
}

// CancelAndReset always calls Reset, including when IPC fails.
func CancelAndReset(ctx context.Context, shell Shell, submap stt.Submap) error {
	ipcErr := Cancel(ctx, shell)
	resetCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 3*time.Second)
	defer cancel()
	resetErr := submap.Reset(resetCtx)
	return errors.Join(ipcErr, resetErr)
}

type notifier struct{}

func NewNotifier() stt.Notifier { return &notifier{} }

func (*notifier) Notify(ctx context.Context, summary, body string) error {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		return fmt.Errorf("conectar al bus de sesión: %w", err)
	}
	defer conn.Close()
	var id uint32
	call := conn.Object("org.freedesktop.Notifications", "/org/freedesktop/Notifications").CallWithContext(
		ctx, "org.freedesktop.Notifications.Notify", 0,
		"Senda", uint32(0), "", summary, body, []string{}, map[string]dbus.Variant{}, int32(5000),
	)
	if err := call.Store(&id); err != nil {
		return fmt.Errorf("enviar notificación: %w", err)
	}
	return nil
}
