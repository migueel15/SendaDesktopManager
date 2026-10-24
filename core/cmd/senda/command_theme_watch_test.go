package main

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/theme"
)

func TestThemeWatchStableChanges(t *testing.T) {
	input, options := saveFixture(t)
	info, err := saveUserTheme(input, options)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ticks := make(chan time.Time)
	ready := make(chan struct{})
	nextTick := func() error {
		select {
		case ready <- struct{}{}:
		case <-ctx.Done():
			return ctx.Err()
		}
		select {
		case <-ticks:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	reader, writer := io.Pipe()
	defer reader.Close()
	lines := make(chan theme.Info, 8)
	go func() {
		defer close(lines)
		scanner := bufio.NewScanner(reader)
		for scanner.Scan() {
			var value theme.Info
			if json.Unmarshal(scanner.Bytes(), &value) == nil {
				lines <- value
			}
		}
	}()
	notifications := make(chan theme.Info, 8)
	done := make(chan error, 1)
	go func() {
		done <- watchTheme(ctx, options.dirs, input.Name, input.Name, nextTick, writer, func(info theme.Info) { notifications <- info })
		writer.Close()
	}()
	poll := func() {
		t.Helper()
		select {
		case ticks <- time.Now():
		case <-time.After(3 * time.Second):
			t.Fatal("poll timeout")
		}
		select {
		case <-ready:
		case <-time.After(3 * time.Second):
			t.Fatal("poll completion timeout")
		}
	}
	receive := func(valid bool, field string) theme.Info {
		t.Helper()
		select {
		case value := <-lines:
			if value.Valid != valid || value.Field != field || !value.Active {
				t.Fatalf("unexpected output %+v", value)
			}
			return value
		case <-time.After(3 * time.Second):
			t.Fatal("output timeout")
		}
		return theme.Info{}
	}
	change := func(fn func()) {
		t.Helper()
		fn()
		poll()
		select {
		case value := <-lines:
			t.Fatalf("unstable output %+v", value)
		default:
		}
		poll()
	}
	select {
	case <-ready:
	case <-time.After(3 * time.Second):
		t.Fatal("watch start timeout")
	}
	value, err := theme.Load(info.File)
	if err != nil {
		t.Fatal(err)
	}
	modified := time.Now()
	writeJSON := func() {
		t.Helper()
		data, _ := json.Marshal(value)
		if err := os.WriteFile(info.File, data, 0600); err != nil {
			t.Fatal(err)
		}
		modified = modified.Add(time.Second)
		if err := os.Chtimes(info.File, modified, modified); err != nil {
			t.Fatal(err)
		}
	}
	change(func() { value.Colors["base"] = "#abcdef"; writeJSON() })
	if got := receive(true, ""); got.Colors["base"] != "#abcdef" {
		t.Fatal(got)
	}
	change(func() {
		if err := os.WriteFile(info.File, []byte("{"), 0600); err != nil {
			t.Fatal(err)
		}
	})
	receive(false, "json")
	select {
	case notification := <-notifications:
		if notification.Field != "json" {
			t.Fatal(notification)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("missing notification")
	}
	change(writeJSON)
	receive(true, "")
	change(func() { writeThemeImage(t, info.Wallpaper, 4) })
	receive(true, "")
	next := filepath.Join(info.Dir, "next.png")
	change(func() { writeThemeImage(t, next, 5); value.Wallpaper = "next.png"; writeJSON() })
	if got := receive(true, ""); got.Wallpaper != next {
		t.Fatal(got)
	}
	change(func() { writeThemeImage(t, next, 6) })
	receive(true, "")
	external := filepath.Join(t.TempDir(), "external.png")
	change(func() { value.Wallpaper = external; writeJSON() })
	receive(false, "wallpaper")
	change(func() { writeThemeImage(t, external, 7) })
	if got := receive(true, ""); got.Wallpaper != external {
		t.Fatal(got)
	}
	change(func() {
		if err := os.RemoveAll(info.Dir); err != nil {
			t.Fatal(err)
		}
	})
	receive(false, "name")
	poll()
	cancel()
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("watch failed to stop")
	}
}

func TestThemeWatchCommandRejectsInvalidArguments(t *testing.T) {
	for _, args := range [][]string{{"custom", "--interval", "0s"}, {"../escape"}} {
		cmd := themeWatchCmd()
		cmd.SetArgs(args)
		if err := cmd.Execute(); err == nil {
			t.Fatalf("accepted %v", args)
		}
	}
}

// Cancellation works with stdin that would fail immediately if read.
type forbiddenThemeStdin struct{ t *testing.T }

func (r forbiddenThemeStdin) Read([]byte) (int, error) {
	r.t.Error("watch read stdin")
	return 0, io.ErrUnexpectedEOF
}

func TestThemeWatchCommandIgnoresStdin(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("SENDA_HOME", t.TempDir())
	cmd := themeWatchCmd()
	cmd.SetArgs([]string{"missing"})
	cmd.SetIn(forbiddenThemeStdin{t})
	if err := cmd.ExecuteContext(ctx); err != nil {
		t.Fatal(err)
	}
}
