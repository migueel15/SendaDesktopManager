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

type dictation struct {
	p                         *process
	results                   chan stt.Result
	ready, done               chan struct{}
	command, final            string
	err                       error
	isReady, ended, finalSeen bool
}

func newDictation(p *process) *dictation {
	return &dictation{p: p, results: make(chan stt.Result, 1), ready: make(chan struct{}), done: make(chan struct{})}
}

type process struct {
	loaded       chan struct{}
	loadedClosed bool
	standby      bool
	current      *dictation
	cmd          *exec.Cmd
	stdin        io.WriteCloser
	done         chan struct{}
	mu           sync.Mutex
	err          error
	command      string
	killOnce     sync.Once
}

// closeLoaded and complete are called with the process mutex held.
func (p *process) closeLoaded() {
	if !p.loadedClosed {
		close(p.loaded)
		p.loadedClosed = true
	}
}

func (d *dictation) complete(err error) {
	if d.ended {
		return
	}
	d.err, d.ended = err, true
	close(d.results)
	close(d.done)
	if d.p.standby {
		d.p.loaded = make(chan struct{})
		d.p.loadedClosed = false
	}
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
	_, err = p.current.waitReady(ctx)
	if err != nil {
		return nil, err
	}
	return p, nil
}

func prepareProcess(ctx context.Context, cmd *exec.Cmd) (*process, error) {
	return launchProcess(ctx, cmd, true)
}

func launchProcess(ctx context.Context, cmd *exec.Cmd, standby bool) (*process, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	p := &process{loaded: make(chan struct{}), standby: standby, cmd: cmd, done: make(chan struct{})}
	if !standby {
		p.current = newDictation(p)
	}
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

func (d *dictation) waitReady(ctx context.Context) (stt.Stream, error) {
	p := d.p
	select {
	case <-d.ready:
		return d, nil
	case <-p.done:
		if err := p.Err(); err != nil {
			return nil, err
		}
		return nil, fmt.Errorf("El motor de voz terminó antes de iniciar la grabación")
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
		p.mu.Lock()
		d := p.current
		switch {
		case e.Type == stt.EventLoaded && p.standby && !p.loadedClosed && (d == nil || d.ended):
			p.closeLoaded()
		case e.Type == stt.EventReady && d != nil && !d.isReady && !d.ended:
			d.isReady = true
			close(d.ready)
		case d != nil && d.isReady && !d.ended && !d.finalSeen && (e.Type == stt.EventPartial || e.Type == stt.EventFinal):
			d.final = e.Text
			d.finalSeen = e.Type == stt.EventFinal
			select {
			case <-d.results:
			default:
			}
			d.results <- stt.Result{Text: e.Text}
			if d.finalSeen && p.standby {
				d.complete(nil)
			}
		// A partial already in flight when cancel was sent can be discarded.
		case d != nil && d.ended && d.command == stt.CommandCancel && e.Type == stt.EventPartial:
		default:
			if p.err == nil {
				p.err = fmt.Errorf("Secuencia no válida del motor de voz: %s", e.Type)
			}
		}
		failed := p.err != nil
		p.mu.Unlock()
		if failed {
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
	d := p.current
	clean := p.command == stt.CommandCancel || (d != nil && (d.command == stt.CommandCancel || d.finalSeen))
	if p.standby && p.loadedClosed && (d == nil || d.ended) {
		clean = true
	}
	if p.err == nil && (err != nil || !clean) {
		p.err = fmt.Errorf("El motor de voz terminó inesperadamente: %v %s", err, stderr.String())
	}
	if d != nil {
		d.complete(p.err)
	}
	p.closeLoaded()
	close(p.done)
	p.mu.Unlock()
}

func (p *process) Results() <-chan stt.Result   { return p.current.results }
func (p *process) Err() error                   { p.mu.Lock(); defer p.mu.Unlock(); return p.err }
func (d *dictation) Results() <-chan stt.Result { return d.results }
func (d *dictation) Err() error                 { d.p.mu.Lock(); defer d.p.mu.Unlock(); return d.err }

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
	if !p.standby {
		return p.current.finish(ctx, command)
	}
	p.mu.Lock()
	select {
	case <-p.done:
	default:
		if p.command == "" {
			p.command = command
			if p.current != nil && !p.current.ended && command == stt.CommandCancel {
				p.current.command = command
				p.current.final = ""
				p.current.complete(nil)
			}
			if _, err := io.WriteString(p.stdin, command+"\n"); err != nil && p.err == nil {
				p.err = fmt.Errorf("No se pudo detener el motor de voz: %w", err)
				p.terminate()
			}
			// EOF also ends a resident process if cancel arrived during recording.
			p.stdin.Close()
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
	return "", p.err
}

func (d *dictation) finish(ctx context.Context, command string) (string, error) {
	p := d.p
	p.mu.Lock()
	if d.ended {
		text, err := d.final, d.err
		p.mu.Unlock()
		return text, err
	}
	if d.command == "" {
		d.command = command
		if _, err := io.WriteString(p.stdin, command+"\n"); err != nil {
			if p.err == nil {
				p.err = fmt.Errorf("No se pudo detener el motor de voz: %w", err)
			}
			p.terminate()
		} else if p.standby && command == stt.CommandCancel {
			d.final = ""
			d.complete(nil)
		}
	}
	p.mu.Unlock()
	select {
	case <-d.done:
	case <-ctx.Done():
		p.fail(ctx.Err())
		p.terminate()
		<-p.done
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	return d.final, d.err
}
func (d *dictation) Stop(ctx context.Context) (string, error) { return d.finish(ctx, stt.CommandStop) }
func (d *dictation) Cancel(ctx context.Context) error {
	_, err := d.finish(ctx, stt.CommandCancel)
	return err
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

func (p *process) Loaded() <-chan struct{} {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.loaded
}

func (p *process) Begin(ctx context.Context) (stt.Stream, error) {
	select {
	case <-p.Loaded():
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
	select {
	case <-p.done:
		p.mu.Unlock()
		return nil, fmt.Errorf("El motor de voz ya está detenido")
	default:
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
	if p.current == nil || p.current.ended {
		p.current = newDictation(p)
		if _, err := io.WriteString(p.stdin, stt.CommandStart+"\n"); err != nil {
			p.err = fmt.Errorf("No se pudo iniciar la grabación: %w", err)
			p.terminate()
		}
	}
	d := p.current
	p.mu.Unlock()
	return d.waitReady(ctx)
}
