package usb

import (
	"testing"

	"github.com/godbus/dbus/v5"
)

func v(value any) dbus.Variant { return dbus.MakeVariant(value) }

func TestMountable(t *testing.T) {
	block := func() properties {
		return properties{"IdUsage": v("filesystem"), "HintAuto": v(true), "HintIgnore": v(false), "HintSystem": v(false)}
	}
	drive := properties{"ConnectionBus": v("usb"), "Removable": v(true)}
	if !mountable(block(), drive) {
		t.Fatal("USB filesystem should mount")
	}
	if !mountable(block(), properties{"ConnectionBus": v("usb"), "MediaRemovable": v(true)}) {
		t.Fatal("removable media should mount")
	}
	for name, change := range map[string]func(properties){
		"ignored":   func(p properties) { p["HintIgnore"] = v(true) },
		"system":    func(p properties) { p["HintSystem"] = v(true) },
		"no auto":   func(p properties) { p["HintAuto"] = v(false) },
		"encrypted": func(p properties) { p["IdUsage"] = v("crypto") },
	} {
		props := block()
		change(props)
		if mountable(props, drive) {
			t.Errorf("%s should not mount", name)
		}
	}
	if mountable(block(), properties{"ConnectionBus": v("sdio"), "Removable": v(true)}) {
		t.Error("non USB drive should not mount")
	}
	if mountable(block(), properties{"ConnectionBus": v("usb")}) {
		t.Error("fixed USB disk should not mount")
	}
}

func TestDeviceName(t *testing.T) {
	if got := deviceName(properties{"IdLabel": v("DATOS")}, "/run/media/u/x"); got != "DATOS" {
		t.Fatal(got)
	}
	if got := deviceName(properties{}, "/run/media/u/AB12"); got != "AB12" {
		t.Fatal(got)
	}
}

func TestIsAutomounter(t *testing.T) {
	if !isAutomounter("udiskie\n", nil) {
		t.Fatal("comm")
	}
	if !isAutomounter("python3\n", []byte("/usr/bin/python\x00/usr/bin/udiskie\x00--tray\x00")) {
		t.Fatal("script")
	}
	if isAutomounter("vim\n", []byte("vim\x00notes\x00udiskie\x00")) {
		t.Fatal("argument is not the program")
	}
}

func TestAddedFilesystem(t *testing.T) {
	path := dbus.ObjectPath("/org/freedesktop/UDisks2/block_devices/sdb1")
	body := func(iface string) []any {
		return []any{path, map[string]map[string]dbus.Variant{iface: {}}}
	}
	if got, ok := addedFilesystem(&dbus.Signal{Name: signalInterface, Body: body(fsInterface)}); !ok || got != path {
		t.Fatal(got, ok)
	}
	if _, ok := addedFilesystem(&dbus.Signal{Name: signalInterface, Body: body(blockInterface)}); ok {
		t.Fatal("block alone has nothing to mount")
	}
}
