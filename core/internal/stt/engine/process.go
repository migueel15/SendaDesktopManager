package engine

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type process struct {
	loaded      chan struct{}
	loadedOnce  sync.Once
	standby     bool
	begun       bool
	cmd         *exec.Cmd
	stdin       io.WriteCloser
	results     chan stt.Result
	ready, done chan struct{}
	mu          sync.Mutex
	err         error
	final       string
	command     string
	killOnce    sync.Once
}

type diagnostics []byte

func (b *diagnostics) Write(data []byte) (int, error) {
	n := len(data)
	*b = append(*b, data...)
	if len(*b) > 8192 {
		*b = (*b)[len(*b)-8192:]
	}
	return n, nil
}

func (b *diagnostics) String() string { return string(*b) }

func startProcess(ctx context.Context, cmd *exec.Cmd) (*process, error) {
	p, err := launchProcess(ctx, cmd, false)
	if err != nil {
		return nil, err
	}
	return p.waitReady(ctx)
}

func prepareProcess(ctx context.Context, cmd *exec.Cmd) (*process, error) {
	return launchProcess(ctx, cmd, true)
}

func launchProcess(ctx context.Context, cmd *exec.Cmd, standby bool) (*process, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	p := &process{loaded: make(chan struct{}), standby: standby, cmd: cmd, results: make(chan stt.Result, 1), ready: make(chan struct{}), done: make(chan struct{})}
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	var stderr diagnostics
	cmd.Stderr = io.MultiWriter(os.Stderr, &stderr)
	var err error
	if p.stdin, err = cmd.StdinPipe(); err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		p.stdin.Close()
		return nil, err
	}
	if err = cmd.Start(); err != nil {
		p.stdin.Close()
		stdout.Close()
		return nil, fmt.Errorf("No se pudo iniciar el motor de voz: %w", err)
	}
	go p.read(stdout, &stderr)
	go func() {
		select {
		case <-ctx.Done():
			p.fail(ctx.Err())
			p.terminate()
		case <-p.done:
		}
	}()
	return p, nil
}

func (p *process) waitReady(ctx context.Context) (*process, error) {
	select {
	case <-p.ready:
		return p, nil
	case <-p.done:
		if err := p.Err(); err != nil {
			return nil, err
		}
		select {
		case <-p.ready:
			return p, nil
		default:
			return nil, fmt.Errorf("El motor de voz terminó antes de iniciar la grabación")
		}
	case <-ctx.Done():
		p.fail(ctx.Err())
		p.terminate()
		<-p.done
		return nil, ctx.Err()
	}
}

func (p *process) fail(err error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	select {
	case <-p.done:
		return
	default:
	}
	if p.err == nil {
		p.err = err
	}
}

func (p *process) read(stdout io.ReadCloser, stderr *diagnostics) {
	loaded, ready, final := false, false, false
	scanner := bufio.NewScanner(stdout)
	scanner.Buffer(make([]byte, 4096), 4*1024*1024)
	for scanner.Scan() {
		var e stt.Event
		if err := json.Unmarshal(scanner.Bytes(), &e); err != nil {
			p.fail(fmt.Errorf("Respuesta no válida del motor de voz: %w", err))
			break
		}
		if e.Type == stt.EventError {
			p.fail(fmt.Errorf("No se pudo transcribir el audio: %s", e.Message))
			break
		}
		switch {
		case e.Type == stt.EventLoaded && p.standby && !loaded && !ready:
			loaded = true
			p.loadedOnce.Do(func() { close(p.loaded) })
		case e.Type == stt.EventReady && !ready && (!p.standby || (loaded && p.hasBegun())):
			ready = true
			close(p.ready)
		case ready && (e.Type == stt.EventPartial || e.Type == stt.EventFinal):
			p.mu.Lock()
			p.final = e.Text
			p.mu.Unlock()
			final = e.Type == stt.EventFinal
			// Keep the newest complete result even when a consumer is slow.
			select {
			case <-p.results:
			default:
			}
			p.results <- stt.Result{Text: e.Text}
		default:
			p.fail(fmt.Errorf("Secuencia no válida del motor de voz: %s", e.Type))
		}
		if p.Err() != nil {
			break
		}
	}
	if err := scanner.Err(); err != nil {
		p.fail(fmt.Errorf("No se pudo leer el motor de voz: %w", err))
	}
	if p.Err() != nil {
		p.terminate()
	}
	stdout.Close()
	err := p.cmd.Wait()
	// Also reap the recorder if Python died without running its finally block.
	syscall.Kill(-p.cmd.Process.Pid, syscall.SIGKILL)
	p.stdin.Close()
	p.mu.Lock()
	if p.err == nil && (err != nil || (p.command != stt.CommandCancel && (!ready || !final))) {
		p.err = fmt.Errorf("El motor de voz terminó inesperadamente: %v %s", err, stderr.String())
	}
	p.loadedOnce.Do(func() { close(p.loaded) })
	close(p.results)
	close(p.done)
	p.mu.Unlock()
}

func (p *process) Results() <-chan stt.Result { return p.results }
func (p *process) Err() error                 { p.mu.Lock(); defer p.mu.Unlock(); return p.err }

func (p *process) terminate() {
	select {
	case <-p.done:
		return
	default:
	}
	p.killOnce.Do(func() {
		syscall.Kill(-p.cmd.Process.Pid, syscall.SIGTERM)
		go func() {
			select {
			case <-p.done:
			case <-time.After(150 * time.Millisecond):
				syscall.Kill(-p.cmd.Process.Pid, syscall.SIGKILL)
			}
		}()
	})
}

func (p *process) finish(ctx context.Context, command string) (string, error) {
	p.mu.Lock()
	select {
	case <-p.done:
	default:
		if p.command == "" {
			p.command = command
			if _, err := io.WriteString(p.stdin, command+"\n"); err != nil && p.err == nil {
				p.err = fmt.Errorf("No se pudo detener el motor de voz: %w", err)
				p.terminate()
			}
		}
	}
	p.mu.Unlock()
	select {
	case <-p.done:
	case <-ctx.Done():
		p.fail(ctx.Err())
		p.terminate()
		<-p.done
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.final, p.err
}

func (p *process) Stop(ctx context.Context) (string, error) { return p.finish(ctx, stt.CommandStop) }
func (p *process) Cancel(ctx context.Context) error {
	_, err := p.finish(ctx, stt.CommandCancel)
	return err
}

// Prepare starts loading the recognizer without opening the microphone.
func (e *engine) Prepare(ctx context.Context, opts stt.EngineOptions) (stt.Standby, error) {
	m, err := stt.ReadManifest(opts.ModelDir)
	if err != nil {
		return nil, fmt.Errorf("No se pudo leer el modelo: %w", err)
	}
	if m.Kind != "transducer" || m.Encoder == "" || m.Decoder == "" || m.Joiner == "" || m.Tokens == "" {
		return nil, fmt.Errorf("El manifiesto del modelo no contiene un transductor completo")
	}
	python := e.python
	if python == "" {
		python = Python()
	}
	if python == "" {
		return nil, fmt.Errorf("El entorno de reconocimiento de voz no está instalado")
	}
	provider := opts.Provider
	if provider == "" || provider == "auto" {
		provider = RuntimeProvider()
		if provider == "" {
			provider = "cpu"
		}
	}
	if provider != "cpu" && provider != "cuda" {
		return nil, fmt.Errorf("Proveedor de reconocimiento no válido: %s", provider)
	}
	path, err := writeScript(filepath.Dir(filepath.Dir(python)))
	if err != nil {
		return nil, fmt.Errorf("No se pudo preparar el motor de voz: %w", err)
	}
	manifest, _ := json.Marshal(m)
	return prepareProcess(ctx, exec.Command(python, "-u", path, "--model-dir", opts.ModelDir,
		"--manifest", string(manifest), "--provider", provider, "--language", opts.Language, "--standby"))
}

func (p *process) Loaded() <-chan struct{} { return p.loaded }

func (p *process) hasBegun() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.begun
}

func (p *process) Begin(ctx context.Context) (stt.Stream, error) {
	select {
	case <-p.loaded:
	case <-ctx.Done():
		p.fail(ctx.Err())
		p.terminate()
		<-p.done
		return nil, ctx.Err()
	}
	p.mu.Lock()
	if p.err != nil {
		err := p.err
		p.mu.Unlock()
		return nil, err
	}
	if p.command != "" {
		p.mu.Unlock()
		return nil, fmt.Errorf("El motor de voz ya está detenido")
	}
	if err := ctx.Err(); err != nil {
		p.mu.Unlock()
		p.fail(err)
		p.terminate()
		<-p.done
		return nil, err
	}
	if !p.begun {
		p.begun = true
		if _, err := io.WriteString(p.stdin, stt.CommandStart+"\n"); err != nil {
			p.err = fmt.Errorf("No se pudo iniciar la grabación: %w", err)
			p.terminate()
		}
	}
	p.mu.Unlock()
	stream, err := p.waitReady(ctx)
	if err != nil {
		return nil, err
	}
	return stream, nil
}
