package keyboard

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
)

type State struct {
	Status  string   `json:"status"`
	Devices []string `json:"devices"`
}
type Controller struct {
	Directory string
	Detect    func() ([]Device, error)
	Apply     func(string, bool) error
	Locked    func() (bool, error)
}

func DefaultController(locked func() (bool, error)) Controller {
	return Controller{Directory: filepath.Join(os.Getenv("XDG_RUNTIME_DIR"), "senda"), Locked: locked,
		Detect: func() ([]Device, error) {
			b, e := exec.Command("hyprctl", "devices", "-j").Output()
			if e != nil {
				return nil, e
			}
			return DefaultDetector().Detect(b)
		},
		Apply: func(name string, on bool) error {
			code := "hl.device({name=" + strconv.Quote(name) + ", enabled=" + strconv.FormatBool(on) + "})"
			out, e := exec.Command("hyprctl", "eval", code).CombinedOutput()
			if e != nil {
				return fmt.Errorf("%s: %w: %s", name, e, strings.TrimSpace(string(out)))
			}
			if strings.TrimSpace(string(out)) != "ok" {
				return fmt.Errorf("%s: %s", name, strings.TrimSpace(string(out)))
			}
			return nil
		},
	}
}

func (c Controller) withLock(fn func() (State, error)) (State, error) {
	if c.Directory == "senda" || c.Directory == "" {
		return State{}, errors.New("XDG_RUNTIME_DIR no definido")
	}
	if err := os.MkdirAll(c.Directory, 0700); err != nil {
		return State{}, err
	}
	f, err := os.OpenFile(filepath.Join(c.Directory, "keyboard.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return State{}, err
	}
	defer f.Close()
	if err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return State{}, err
	}
	defer syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
	return fn()
}
func (c Controller) read() (State, error) {
	b, err := os.ReadFile(filepath.Join(c.Directory, "keyboard.json"))
	if errors.Is(err, os.ErrNotExist) {
		return State{Status: "on"}, nil
	}
	if err != nil {
		return State{}, err
	}
	var s State
	if err = json.Unmarshal(b, &s); err != nil {
		return State{}, err
	}
	if s.Status != "on" && s.Status != "off" && s.Status != "error" {
		return State{}, errors.New("estado de teclado inválido")
	}
	return s, nil
}
func (c Controller) write(s State) error {
	b, err := json.Marshal(s)
	if err != nil {
		return err
	}
	f, err := os.CreateTemp(c.Directory, ".keyboard-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if err = f.Chmod(0600); err == nil {
		_, err = f.Write(b)
	}
	if err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	return os.Rename(f.Name(), filepath.Join(c.Directory, "keyboard.json"))
}
func (c Controller) Status() (State, error) { return c.withLock(c.read) }
func (c Controller) Reset() (State, error) {
	return c.withLock(func() (State, error) { s := State{Status: "on"}; return s, c.write(s) })
}
func (c Controller) Set(action string) (State, error) {
	return c.withLock(func() (State, error) {
		previous, err := c.read()
		if err != nil {
			return State{}, err
		}
		on := action == "on" || (action == "toggle" && previous.Status != "on")
		if action != "on" && action != "off" && action != "toggle" {
			return previous, errors.New("acción inválida")
		}
		if !on {
			if c.Locked == nil {
				return previous, errors.New("no se puede comprobar el bloqueo de pantalla")
			}
			locked, e := c.Locked()
			if e != nil {
				return previous, e
			}
			if locked {
				return previous, errors.New("la pantalla está bloqueada")
			}
			if previous.Status == "off" {
				return previous, nil
			}
			if previous.Status == "error" {
				return previous, errors.New("recupera primero el teclado con on")
			}
		}
		devices, err := c.Detect()
		if err != nil {
			return previous, err
		}
		names := map[string]bool{}
		if on {
			for _, name := range previous.Devices {
				names[name] = true
			}
		}
		for _, device := range devices {
			if device.Included {
				for _, name := range device.Hyprland {
					names[name] = true
				}
			} else if device.Reason == "sin correspondencia en Hyprland" {
				fmt.Fprintf(os.Stderr, "Aviso: %s sin correspondencia en Hyprland\n", device.Name)
			}
		}
		list := make([]string, 0, len(names))
		for name := range names {
			list = append(list, name)
		}
		sort.Strings(list)
		applied := []string{}
		wasDisabled := map[string]bool{}
		if previous.Status == "off" {
			for _, name := range previous.Devices {
				wasDisabled[name] = true
			}
		}
		rollback := func() {
			for _, done := range applied {
				if !on {
					_ = c.Apply(done, true)
				} else if wasDisabled[done] {
					_ = c.Apply(done, false)
				}
			}
		}
		for _, name := range list {
			if err = c.Apply(name, on); err != nil {
				rollback()
				failed := State{Status: "error", Devices: list}
				writeErr := c.write(failed)
				return failed, errors.Join(err, writeErr)
			}
			applied = append(applied, name)
		}
		next := State{Status: "on"}
		if !on {
			next = State{Status: "off", Devices: list}
		}
		if err = c.write(next); err != nil {
			rollback()
			return previous, err
		}
		return next, nil
	})
}
