// Package usb mounts removable filesystems through udisks as they appear, so
// the user needs neither sudo nor a separate automounter.
package usb

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
	"github.com/migueel15/SendaDesktopManager/core/internal/notify"
)

const (
	busName         = "org.freedesktop.UDisks2"
	blockInterface  = "org.freedesktop.UDisks2.Block"
	driveInterface  = "org.freedesktop.UDisks2.Drive"
	fsInterface     = "org.freedesktop.UDisks2.Filesystem"
	alreadyMounted  = "org.freedesktop.UDisks2.Error.AlreadyMounted"
	propertiesGet   = "org.freedesktop.DBus.Properties.GetAll"
	objectManager   = "org.freedesktop.DBus.ObjectManager"
	instanceName    = "net.dorlab.Senda.UsbWatcher"
	settleDelay     = 500 * time.Millisecond
	managerPath     = dbus.ObjectPath("/org/freedesktop/UDisks2")
	signalInterface = objectManager + ".InterfacesAdded"
)

// automounters are the programs that mount removable media on their own.
var automounters = map[string]bool{"udiskie": true, "devmon": true, "udevil": true}

type properties = map[string]dbus.Variant

func text(props properties, name string) string {
	value, _ := props[name].Value().(string)
	return value
}

func flag(props properties, name string) bool {
	value, _ := props[name].Value().(bool)
	return value
}

// mountable reports whether a block device is a filesystem on a removable USB
// drive that udisks does not ask to leave alone.
func mountable(block, drive properties) bool {
	if text(block, "IdUsage") != "filesystem" || flag(block, "HintIgnore") || flag(block, "HintSystem") || !flag(block, "HintAuto") {
		return false
	}
	return text(drive, "ConnectionBus") == "usb" && (flag(drive, "Removable") || flag(drive, "MediaRemovable"))
}

// deviceName picks the name shown in the notification.
func deviceName(block properties, mountPoint string) string {
	if label := text(block, "IdLabel"); label != "" {
		return label
	}
	return filepath.Base(mountPoint)
}

// isAutomounter reports whether a process, given its comm and NUL-separated
// command line, is an automounter. Script interpreters hide the name in the
// second argument.
func isAutomounter(comm string, cmdline []byte) bool {
	if automounters[strings.TrimSpace(comm)] {
		return true
	}
	args := strings.Split(string(cmdline), "\x00")
	for _, arg := range args[:min(2, len(args))] {
		if automounters[filepath.Base(arg)] {
			return true
		}
	}
	return false
}

// automounterRunning scans the current user's processes for an automounter.
func automounterRunning() bool {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return false
	}
	uid := os.Getuid()
	for _, entry := range entries {
		dir := filepath.Join("/proc", entry.Name())
		if info, err := entry.Info(); err != nil || !entry.IsDir() || ownerOf(info) != uid {
			continue
		}
		comm, err := os.ReadFile(filepath.Join(dir, "comm"))
		if err != nil {
			continue
		}
		cmdline, _ := os.ReadFile(filepath.Join(dir, "cmdline"))
		if isAutomounter(string(comm), cmdline) {
			return true
		}
	}
	return false
}

func getAll(conn *dbus.Conn, path dbus.ObjectPath, iface string) (properties, error) {
	var props properties
	err := conn.Object(busName, path).Call(propertiesGet, 0, iface).Store(&props)
	return props, err
}

// mount mounts the filesystem at path when it qualifies. It returns the block
// properties and mount point, or an empty mount point when nothing was mounted.
func mount(conn *dbus.Conn, path dbus.ObjectPath) (properties, string, error) {
	block, err := getAll(conn, path, blockInterface)
	if err != nil {
		return nil, "", err
	}
	drivePath, _ := block["Drive"].Value().(dbus.ObjectPath)
	if drivePath == "" || drivePath == "/" {
		return nil, "", nil
	}
	drive, err := getAll(conn, drivePath, driveInterface)
	if err != nil {
		return nil, "", err
	}
	if !mountable(block, drive) {
		return nil, "", nil
	}
	options := map[string]dbus.Variant{"auth.no_user_interaction": dbus.MakeVariant(true)}
	var mountPoint string
	err = conn.Object(busName, path).Call(fsInterface+".Mount", 0, options).Store(&mountPoint)
	var failure dbus.Error
	// Someone else got there first: that mount is not ours to announce.
	if errors.As(err, &failure) && failure.Name == alreadyMounted {
		return nil, "", nil
	}
	return block, mountPoint, err
}

func handle(conn *dbus.Conn, path dbus.ObjectPath) {
	// udisks publishes the object before its last property updates.
	time.Sleep(settleDelay)
	if automounterRunning() {
		return
	}
	block, mountPoint, err := mount(conn, path)
	if err != nil {
		_ = notify.Send("No se pudo montar el dispositivo USB", err.Error())
		return
	}
	if mountPoint != "" {
		_ = notify.Send("Dispositivo USB conectado", deviceName(block, mountPoint)+" en "+mountPoint)
	}
}

// addedFilesystem extracts the object path of an InterfacesAdded signal that
// brings a filesystem.
func addedFilesystem(signal *dbus.Signal) (dbus.ObjectPath, bool) {
	if signal.Name != signalInterface || len(signal.Body) != 2 {
		return "", false
	}
	path, ok := signal.Body[0].(dbus.ObjectPath)
	interfaces, valid := signal.Body[1].(map[string]map[string]dbus.Variant)
	if !ok || !valid {
		return "", false
	}
	_, found := interfaces[fsInterface]
	return path, found
}

// claimInstance owns the watcher name and returns a channel closed when a newer
// watcher replaces this one, so an orphan from an earlier shell steps aside.
func claimInstance(ctx context.Context) (<-chan struct{}, error) {
	session, err := dbus.ConnectSessionBus()
	if err != nil {
		return nil, err
	}
	lost := make(chan *dbus.Signal, 4)
	session.Signal(lost)
	if err := session.AddMatchSignal(dbus.WithMatchInterface("org.freedesktop.DBus"), dbus.WithMatchMember("NameLost")); err != nil {
		session.Close()
		return nil, err
	}
	reply, err := session.RequestName(instanceName, dbus.NameFlagAllowReplacement|dbus.NameFlagReplaceExisting|dbus.NameFlagDoNotQueue)
	if err != nil {
		session.Close()
		return nil, err
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		session.Close()
		return nil, errors.New("otro vigilante USB tiene el nombre")
	}
	replaced := make(chan struct{})
	go func() {
		defer session.Close()
		defer close(replaced)
		for {
			select {
			case <-ctx.Done():
				return
			case signal, open := <-lost:
				if !open {
					return
				}
				if signal.Name == "org.freedesktop.DBus.NameLost" && len(signal.Body) == 1 && signal.Body[0] == instanceName {
					return
				}
			}
		}
	}()
	return replaced, nil
}

// Watch mounts USB filesystems as they appear until ctx ends, this watcher is
// replaced, or the system bus closes. Devices already connected are left as
// they are, because the user may have unmounted them on purpose.
func Watch(ctx context.Context) error {
	replaced, err := claimInstance(ctx)
	if err != nil {
		return err
	}
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		return err
	}
	defer conn.Close()
	signals := make(chan *dbus.Signal, 16)
	conn.Signal(signals)
	if err := conn.AddMatchSignal(dbus.WithMatchObjectPath(managerPath), dbus.WithMatchInterface(objectManager), dbus.WithMatchMember("InterfacesAdded")); err != nil {
		return err
	}
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-replaced:
			return nil
		case signal, open := <-signals:
			if !open {
				return errors.New("conexión con el bus del sistema cerrada")
			}
			if path, ok := addedFilesystem(signal); ok {
				go handle(conn, path)
			}
		}
	}
}
