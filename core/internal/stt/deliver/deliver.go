// Package deliver transfers recognized text to the clipboard or focused window.
package deliver

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"reflect"
	"strings"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type deliverer struct {
	run, copy stt.Runner
	// detached marks the production wl-copy path, which returns before its
	// background child owns the selection.
	detached bool
}

const (
	clipboardWait  = time.Second
	clipboardRetry = 50 * time.Millisecond
)

func New(run stt.Runner) stt.Deliverer {
	copyRunner := run
	detached := false
	// Preserve injected runners while selecting the noncapturing execution
	// path for the production clipboard command. Other commands need output.
	if run != nil && reflect.ValueOf(run).Pointer() == reflect.ValueOf(stt.ExecRunner).Pointer() {
		copyRunner = stt.DetachedRunner
		detached = true
	}
	return &deliverer{run: run, copy: copyRunner, detached: detached}
}

// waitClipboard polls wl-paste until the selection holds text, so the paste
// does not race the background wl-copy. It gives up when wl-paste fails or the
// wait expires; the paste is still attempted.
func (d *deliverer) waitClipboard(ctx context.Context, text string) {
	deadline := time.Now().Add(clipboardWait)
	for {
		current, err := d.run(ctx, nil, "wl-paste", "-n")
		if err != nil {
			log.Printf("stt delivery: comprobación del portapapeles (wl-paste): %v", err)
			return
		}
		if strings.TrimRight(string(current), "\n") == strings.TrimRight(text, "\n") {
			return
		}
		if time.Now().After(deadline) {
			log.Printf("stt delivery: comprobación del portapapeles: el texto no apareció en %s", clipboardWait)
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(clipboardRetry):
		}
	}
}

func traced(ctx context.Context, run stt.Runner, stdin io.Reader, step, name string, args ...string) ([]byte, error) {
	started := time.Now()
	log.Printf("stt delivery: %s: inicio", step)
	output, err := run(ctx, stdin, name, args...)
	if err != nil {
		err = fmt.Errorf("%s (%s): %w", step, name, err)
	}
	log.Printf("stt delivery: %s: fin (%s), error=%v", step, time.Since(started), err)
	return output, err
}

func (d *deliverer) Deliver(ctx context.Context, text string, s stt.Settings) error {
	if strings.TrimSpace(text) == "" {
		return nil
	}
	if _, err := traced(ctx, d.copy, strings.NewReader(text), "copia", "wl-copy"); err != nil {
		return fmt.Errorf("copiar texto al portapapeles con wl-copy: %w", err)
	}
	if s.PasteMode != stt.PasteDirect {
		return nil
	}
	if d.detached {
		d.waitClipboard(ctx, text)
	}

	args := []string{"-M", "ctrl", "v", "-m", "ctrl"}
	active, err := traced(ctx, d.run, nil, "ventana activa", "hyprctl", "activewindow", "-j")
	if err == nil {
		var window struct {
			Class string `json:"class"`
		}
		if err := json.Unmarshal(active, &window); err != nil {
			log.Printf("stt delivery: ventana activa (hyprctl): respuesta inválida: %v", err)
		} else if isTerminal(window.Class, s.Terminals) {
			args = []string{"-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"}
		}
	}
	if _, err := traced(ctx, d.run, nil, "pegado", "wtype", args...); err != nil {
		return fmt.Errorf("el texto permanece en el portapapeles, pero no se pudo pegar con wtype: %w", err)
	}
	return nil
}

func isTerminal(class string, terminals []string) bool {
	for _, terminal := range terminals {
		if strings.EqualFold(class, terminal) {
			return true
		}
	}
	return false
}
