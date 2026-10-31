// Package bluetooth handles pairing requests initiated by Senda's interface.
package bluetooth

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"
)

const agentPath dbus.ObjectPath = "/net/dorlab/Senda/BluetoothAgent"

var devicePath = regexp.MustCompile(`^/org/bluez/hci[0-9]+/dev_(?:[0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}$`)
var passkeyPattern = regexp.MustCompile(`^[0-9]{1,6}$`)

type response struct {
	ID     uint64 `json:"id"`
	Accept bool   `json:"accept"`
	Value  string `json:"value"`
	Cancel bool   `json:"cancel"`
}

type prompt struct {
	ID   uint64 `json:"id"`
	Kind string `json:"kind"`
	Code string `json:"code,omitempty"`
}

type agent struct {
	ctx       context.Context
	cancel    context.CancelFunc
	owner     string
	device    dbus.ObjectPath
	out       *json.Encoder
	outputMu  sync.Mutex
	requestMu sync.Mutex
	sequence  uint64
	replies   chan response
}

func (a *agent) emit(p prompt) *dbus.Error {
	a.outputMu.Lock()
	defer a.outputMu.Unlock()
	if err := a.out.Encode(p); err != nil {
		a.cancel()
		return dbus.NewError("org.bluez.Error.Canceled", nil)
	}
	return nil
}

func (a *agent) check(sender dbus.Sender, device dbus.ObjectPath) *dbus.Error {
	if string(sender) != a.owner || device != a.device {
		return dbus.NewError("org.bluez.Error.Rejected", nil)
	}
	return nil
}

func (a *agent) ask(sender dbus.Sender, device dbus.ObjectPath, kind, code string) (string, *dbus.Error) {
	if err := a.check(sender, device); err != nil {
		return "", err
	}
	a.requestMu.Lock()
	defer a.requestMu.Unlock()
	a.sequence++
	id := a.sequence
	if err := a.emit(prompt{ID: id, Kind: kind, Code: code}); err != nil {
		return "", err
	}
	for {
		select {
		case <-a.ctx.Done():
			return "", dbus.NewError("org.bluez.Error.Canceled", nil)
		case reply := <-a.replies:
			if reply.ID != id {
				continue
			}
			if !reply.Accept {
				return "", dbus.NewError("org.bluez.Error.Rejected", nil)
			}
			return reply.Value, nil
		}
	}
}

func (a *agent) RequestConfirmation(sender dbus.Sender, device dbus.ObjectPath, key uint32) *dbus.Error {
	_, err := a.ask(sender, device, "confirm", fmt.Sprintf("%06d", key))
	return err
}

func (a *agent) RequestPinCode(sender dbus.Sender, device dbus.ObjectPath) (string, *dbus.Error) {
	value, err := a.ask(sender, device, "pin", "")
	if err == nil && (len(value) < 1 || len(value) > 16) {
		err = dbus.NewError("org.bluez.Error.Rejected", nil)
	}
	return value, err
}

func (a *agent) RequestPasskey(sender dbus.Sender, device dbus.ObjectPath) (uint32, *dbus.Error) {
	value, err := a.ask(sender, device, "passkey", "")
	if err != nil {
		return 0, err
	}
	if !passkeyPattern.MatchString(value) {
		return 0, dbus.NewError("org.bluez.Error.Rejected", nil)
	}
	key, _ := strconv.ParseUint(value, 10, 32)
	return uint32(key), nil
}

func (a *agent) DisplayPinCode(sender dbus.Sender, device dbus.ObjectPath, pin string) *dbus.Error {
	if err := a.check(sender, device); err != nil {
		return err
	}
	return a.emit(prompt{Kind: "display", Code: pin})
}

func (a *agent) DisplayPasskey(sender dbus.Sender, device dbus.ObjectPath, key uint32, entered uint16) *dbus.Error {
	return a.DisplayPinCode(sender, device, fmt.Sprintf("%06d", key))
}

func (a *agent) RequestAuthorization(sender dbus.Sender, device dbus.ObjectPath) *dbus.Error {
	_, err := a.ask(sender, device, "authorize", "")
	return err
}

func (a *agent) AuthorizeService(sender dbus.Sender, device dbus.ObjectPath, uuid string) *dbus.Error {
	_, err := a.ask(sender, device, "service", uuid)
	return err
}

func (a *agent) Cancel(sender dbus.Sender) *dbus.Error {
	if err := a.check(sender, a.device); err != nil {
		return err
	}
	a.cancel()
	return nil
}

func (a *agent) Release(sender dbus.Sender) *dbus.Error { return a.Cancel(sender) }

// Pair registers an application agent and pairs on the same bus connection,
// so BlueZ uses this agent without replacing Blueman's default agent.
// Requests and responses use JSON lines; EOF or cancellation aborts pairing.
func Pair(parent context.Context, path string, input io.Reader, output io.Writer) error {
	if !devicePath.MatchString(path) {
		return fmt.Errorf("ruta de dispositivo Bluetooth no válida")
	}
	ctx, cancel := context.WithTimeout(parent, 2*time.Minute)
	defer cancel()
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return fmt.Errorf("conectar con BlueZ: %w", err)
	}
	defer conn.Close()
	var owner string
	if err := conn.BusObject().CallWithContext(ctx, "org.freedesktop.DBus.GetNameOwner", 0, "org.bluez").Store(&owner); err != nil {
		return fmt.Errorf("buscar BlueZ: %w", err)
	}
	a := &agent{ctx: ctx, cancel: cancel, owner: owner, device: dbus.ObjectPath(path), out: json.NewEncoder(output), replies: make(chan response)}
	if err := conn.Export(a, agentPath, "org.bluez.Agent1"); err != nil {
		return err
	}
	manager := conn.Object(owner, "/org/bluez")
	if err := manager.CallWithContext(ctx, "org.bluez.AgentManager1.RegisterAgent", 0, agentPath, "KeyboardDisplay").Err; err != nil {
		return fmt.Errorf("registrar confirmación Bluetooth: %w", err)
	}
	defer func() {
		cleanup, stop := context.WithTimeout(context.Background(), 3*time.Second)
		defer stop()
		manager.CallWithContext(cleanup, "org.bluez.AgentManager1.UnregisterAgent", 0, agentPath)
	}()
	go func() {
		scanner := bufio.NewScanner(input)
		for scanner.Scan() {
			var reply response
			if json.Unmarshal(scanner.Bytes(), &reply) != nil || reply.Cancel {
				break
			}
			select {
			case a.replies <- reply:
			case <-ctx.Done():
				return
			}
		}
		cancel()
	}()
	device := conn.Object(owner, a.device)
	if err := device.CallWithContext(ctx, "org.bluez.Device1.Pair", 0).Err; err != nil {
		cleanup, stop := context.WithTimeout(context.Background(), 3*time.Second)
		defer stop()
		device.CallWithContext(cleanup, "org.bluez.Device1.CancelPairing", 0)
		return fmt.Errorf("no se pudo emparejar: %w", err)
	}
	if err := a.emit(prompt{Kind: "paired"}); err != nil {
		return err
	}
	if err := device.CallWithContext(ctx, "org.bluez.Device1.Connect", 0).Err; err != nil {
		return fmt.Errorf("dispositivo emparejado, pero no se pudo conectar: %w", err)
	}
	return nil
}
