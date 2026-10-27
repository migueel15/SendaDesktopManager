package binds

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"
)

func TestReloadReportsHyprlandErrors(t *testing.T) {
	for _, test := range []struct {
		name, errorText, output string
		failReload              bool
	}{
		{name: "reload command", errorText: "unknown option", output: "unknown option", failReload: true},
		{name: "config errors", errorText: "invalid bind", output: "invalid bind"},
	} {
		t.Run(test.name, func(t *testing.T) {
			run := func(_ context.Context, _ io.Reader, _ string, args ...string) ([]byte, error) {
				if args[0] == "reload" {
					if test.failReload {
						return []byte(test.output), errors.New("exit status 1")
					}
					return []byte("ok\n"), nil
				}
				return []byte(test.output), nil
			}
			if err := Reload(context.Background(), run); err == nil || !strings.Contains(err.Error(), test.errorText) {
				t.Fatalf("Reload() = %v", err)
			}
		})
	}
}

func TestConflictsSkipsOwnBindAndOtherModifiers(t *testing.T) {
	var gotArgs []string
	run := func(_ context.Context, _ io.Reader, name string, args ...string) ([]byte, error) {
		gotArgs = append([]string{name}, args...)
		return []byte(bindsJSON), nil
	}
	conflicts, err := Conflicts(context.Background(), run, "alt+ñ")
	if err != nil || len(conflicts) != 1 || !strings.Contains(conflicts[0], "foreign-tool") {
		t.Fatalf("Conflicts() = %v, %v", conflicts, err)
	}
	if strings.Join(gotArgs, " ") != "hyprctl -j binds" {
		t.Fatalf("runner args = %v", gotArgs)
	}
}

func TestConflictsSkipsDescribedSendaLuaBind(t *testing.T) {
	data := `[{"modmask":8,"submap":"","key":"ntilde","dispatcher":"__lua","arg":"11","description":"Senda STT toggle"},
      {"modmask":8,"submap":"","key":"ntilde","dispatcher":"__lua","arg":"12"}]`
	conflicts, err := Conflicts(context.Background(), fixedRunner(data, nil), "ALT + ntilde")
	if err != nil || len(conflicts) != 1 || conflicts[0] != "un atajo de tu configuración sin descripción" {
		t.Fatalf("Conflicts() = %v, %v", conflicts, err)
	}
}
