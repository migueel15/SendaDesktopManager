// Package instance keeps a background watcher unique through a D-Bus name.
package instance

import (
	"context"
	"errors"

	"github.com/godbus/dbus/v5"
)

// Claim takes name on the session bus. The returned channel closes when a newer
// watcher replaces this one, so an orphan from an earlier shell steps aside.
func Claim(ctx context.Context, name string) (<-chan struct{}, error) {
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
	reply, err := session.RequestName(name, dbus.NameFlagAllowReplacement|dbus.NameFlagReplaceExisting|dbus.NameFlagDoNotQueue)
	if err != nil {
		session.Close()
		return nil, err
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		session.Close()
		return nil, errors.New("otra instancia tiene el nombre " + name)
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
				if signal.Name == "org.freedesktop.DBus.NameLost" && len(signal.Body) == 1 && signal.Body[0] == name {
					return
				}
			}
		}
	}()
	return replaced, nil
}
