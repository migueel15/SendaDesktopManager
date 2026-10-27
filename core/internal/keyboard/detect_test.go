package keyboard

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestDetectPhysicalAndVirtual(t *testing.T) {
	root := t.TempDir()
	sys := filepath.Join(root, "sys/class/input")
	udev := filepath.Join(root, "udev")
	if err := os.MkdirAll(sys, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(udev, 0755); err != nil {
		t.Fatal(err)
	}
	add := func(event, kind, name, minor, property string) {
		t.Helper()
		path := filepath.Join(root, "sys/devices", kind, event)
		if err := os.MkdirAll(filepath.Join(path, "device"), 0755); err != nil {
			t.Fatal(err)
		}
		for file, value := range map[string]string{"dev": "13:" + minor, "device/name": name + "\n"} {
			if err := os.WriteFile(filepath.Join(path, file), []byte(value), 0644); err != nil {
				t.Fatal(err)
			}
		}
		if err := os.Symlink(path, filepath.Join(sys, event)); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(udev, "c13:"+minor), []byte("E:ID_INPUT_KEYBOARD="+property+"\n"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	add("event0", "pci", "Example Keyboard", "1", "1")
	add("event1", "virtual/input", "Virtual Keyboard", "2", "1")
	add("event2", "pci", "Power Button", "3", "0")
	add("event3", "pci", "Missing", "4", "1")
	add("event4", "pci", "Mouse ", "5", "1")
	got, err := (Detector{SysInput: sys, UdevData: udev}).Detect([]byte(`{"keyboards":[{"name":"example-keyboard"},{"name":"example-keyboard-2"},{"name":"mouse-"}]}`))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 5 || !got[0].Included || !reflect.DeepEqual(got[0].Hyprland, []string{"example-keyboard", "example-keyboard-2"}) || got[1].Included || got[2].Included || got[3].Included || !got[4].Included {
		t.Fatalf("unexpected devices: %+v", got)
	}
}
