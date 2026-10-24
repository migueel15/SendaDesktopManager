// Package notify sends desktop notifications through the session bus.
package notify

import "github.com/godbus/dbus/v5"

func arguments(summary, body string) []interface{} {
	return []interface{}{"Senda", uint32(0), "", summary, body, []string{}, map[string]dbus.Variant{}, int32(-1)}
}

func Send(summary, body string) error {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		return err
	}
	defer conn.Close()
	return conn.Object("org.freedesktop.Notifications", "/org/freedesktop/Notifications").Call("org.freedesktop.Notifications.Notify", 0, arguments(summary, body)...).Err
}
