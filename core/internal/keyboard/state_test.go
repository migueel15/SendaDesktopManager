package keyboard

import (
	"errors"
	"reflect"
	"testing"
)

func TestTransitionsAndRollback(t *testing.T) {
	var calls []string
	fail := false
	c := Controller{Directory: t.TempDir(), Locked: func() (bool, error) { return false, nil }, Detect: func() ([]Device, error) { return []Device{{Included: true, Hyprland: []string{"a", "b"}}}, nil }, Apply: func(name string, on bool) error {
		if on {
			calls = append(calls, name+":on")
		} else {
			calls = append(calls, name+":off")
		}
		if fail && name == "b" && !on {
			return errors.New("failed")
		}
		return nil
	}}
	state, err := c.Set("off")
	if err != nil || state.Status != "off" {
		t.Fatalf("off: %+v %v", state, err)
	}
	state, err = c.Set("on")
	if err != nil || state.Status != "on" {
		t.Fatalf("on: %+v %v", state, err)
	}
	calls = nil
	fail = true
	state, err = c.Set("off")
	if err == nil || state.Status != "error" || !reflect.DeepEqual(calls, []string{"a:off", "b:off", "a:on"}) {
		t.Fatalf("rollback: %+v %v %v", state, err, calls)
	}
	state, err = c.Status()
	if err != nil || state.Status != "error" {
		t.Fatalf("status: %+v %v", state, err)
	}
}

func TestLockedRejectsOff(t *testing.T) {
	c := Controller{Directory: t.TempDir(), Locked: func() (bool, error) { return true, nil }}
	if _, err := c.Set("off"); err == nil {
		t.Fatal("off accepted while locked")
	}
}

func TestOnFailureRestoresPreviouslyDisabledDevices(t *testing.T) {
	var calls []string
	fail := false
	c := Controller{Directory: t.TempDir(), Locked: func() (bool, error) { return false, nil }, Detect: func() ([]Device, error) { return []Device{{Included: true, Hyprland: []string{"a", "b"}}}, nil }, Apply: func(name string, on bool) error {
		if on {
			calls = append(calls, name+":on")
		} else {
			calls = append(calls, name+":off")
		}
		if fail && name == "b" && on {
			return errors.New("failed")
		}
		return nil
	}}
	if _, err := c.Set("off"); err != nil {
		t.Fatal(err)
	}
	calls = nil
	fail = true
	state, err := c.Set("on")
	if err == nil || state.Status != "error" || !reflect.DeepEqual(calls, []string{"a:on", "b:on", "a:off"}) {
		t.Fatalf("rollback: %+v %v %v", state, err, calls)
	}
}
