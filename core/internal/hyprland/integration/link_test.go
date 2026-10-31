package integration

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"testing"
)

// fakeHyprland answers the probe as missing until it has been reloaded.
type fakeHyprland struct {
	reloaded bool
	source   string
}

func (f *fakeHyprland) run(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
	switch {
	case name != "hyprctl" || len(args) == 0:
		return nil, os.ErrInvalid
	case args[0] == "repl" && f.reloaded:
		return []byte("1.0\t@" + f.source + "\n"), nil
	case args[0] == "repl":
		return []byte("missing\n"), nil
	case args[0] == "reload":
		f.reloaded = true
		return []byte("ok\n"), nil
	}
	return []byte(""), nil
}

func TestProbe(t *testing.T) {
	f := &fakeHyprland{reloaded: true, source: "/cfg/senda/init.lua"}
	link, err := Probe(context.Background(), f.run)
	if err != nil || !link.Loaded || link.Version != "1.0" || link.Source != "/cfg/senda/init.lua" {
		t.Fatalf("got %+v %v", link, err)
	}
	f.reloaded = false
	if link, err = Probe(context.Background(), f.run); err != nil || link.Loaded {
		t.Fatalf("got %+v %v", link, err)
	}
}

func TestEnsureLinkedAppendsAndReloads(t *testing.T) {
	tempConfig(t)
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "fake")
	main := hyprConfigFile()
	if err := os.MkdirAll(filepath.Dir(main), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(main, []byte("user()"), 0644); err != nil {
		t.Fatal(err)
	}
	f := &fakeHyprland{source: ModulePath()}
	warning, err := EnsureLinked(context.Background(), f.run)
	if err != nil || warning != "" || !f.reloaded {
		t.Fatalf("warning %q err %v reloaded %t", warning, err, f.reloaded)
	}
	data, _ := os.ReadFile(main)
	if string(data) != "user()\n"+managedReference+"\n" {
		t.Fatalf("hyprland.lua: %q", data)
	}
}

func TestEnsureLinkedSkipsLoadedModule(t *testing.T) {
	tempConfig(t)
	t.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "fake")
	f := &fakeHyprland{reloaded: true, source: "/somewhere/else/init.lua"}
	if warning, err := EnsureLinked(context.Background(), f.run); err != nil || warning != "" {
		t.Fatalf("warning %q err %v", warning, err)
	}
	if _, err := os.Stat(hyprConfigFile()); !os.IsNotExist(err) {
		t.Fatalf("hyprland.lua touched: %v", err)
	}
}

func TestLocateFollowsMovedModule(t *testing.T) {
	dir := tempConfig(t)
	t.Cleanup(func() { moduleOverride = "" })
	moved := filepath.Join(dir, "custom", "init.lua")
	if err := os.MkdirAll(filepath.Dir(moved), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(moved, []byte(moduleHeader+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	Locate(Link{Loaded: true, Source: moved})
	if ModulePath() != moved {
		t.Fatalf("got %s", ModulePath())
	}
	user := filepath.Join(dir, "other", "init.lua")
	if err := os.MkdirAll(filepath.Dir(user), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(user, []byte("-- mine\n"), 0600); err != nil {
		t.Fatal(err)
	}
	Locate(Link{Loaded: true, Source: user})
	if ModulePath() == user {
		t.Fatal("followed a file without Senda's header")
	}
}
