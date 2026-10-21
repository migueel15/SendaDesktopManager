package main

import (
	"bytes"
	"encoding/json"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestReadChangesAcceptsEditableSettings(t *testing.T) {
	changes, err := readChanges(strings.NewReader(`{"SENDA_WEATHER_LAT":"39.4","SENDA_GOOGLE_CALENDARS":""}`))
	if err != nil {
		t.Fatalf("readChanges() error = %v", err)
	}
	if changes["SENDA_WEATHER_LAT"] != "39.4" {
		t.Fatalf("changes = %v", changes)
	}
}

func TestConfigSTTDefaultsAndPersistence(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	get := func() map[string]string {
		t.Helper()
		cmd := configGetCmd()
		var out bytes.Buffer
		cmd.SetOut(&out)
		if err := cmd.Execute(); err != nil {
			t.Fatal(err)
		}
		var result struct {
			Values map[string]string `json:"values"`
		}
		if err := json.Unmarshal(out.Bytes(), &result); err != nil {
			t.Fatal(err)
		}
		return result.Values
	}
	defaults := map[string]string{stt.KeyModel: stt.DefaultModelID, stt.KeyLanguage: "es",
		stt.KeyPreload: "false", stt.KeyPasteMode: "paste", stt.KeyShortcut: stt.DefaultShortcut, stt.KeyTerminals: strings.Join(stt.DefaultTerminals, ",")}
	for key, want := range defaults {
		if got := get()[key]; got != want {
			t.Errorf("default %s = %q, want %q", key, got, want)
		}
	}
	if err := config.Set(paths.ConfigFile(), map[string]string{stt.KeyModel: "other-model", stt.KeyShortcut: "SUPER + n"}); err != nil {
		t.Fatal(err)
	}
	cmd := configSetCmd()
	cmd.SetIn(strings.NewReader(`{"SENDA_STT_LANGUAGE":"auto","SENDA_STT_PASTE_MODE":"clipboard","SENDA_STT_TERMINALS":"foot,kitty"}`))
	cmd.SetOut(io.Discard)
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	for key, want := range map[string]string{stt.KeyModel: "other-model", stt.KeyShortcut: "SUPER + n",
		stt.KeyLanguage: "auto", stt.KeyPasteMode: "clipboard", stt.KeyTerminals: "foot,kitty"} {
		if got := get()[key]; got != want {
			t.Errorf("persisted %s = %q, want %q", key, got, want)
		}
	}
	cmd = configSetCmd()
	cmd.SetIn(strings.NewReader(`{"SENDA_STT_LANGUAGE":"","SENDA_STT_PASTE_MODE":"","SENDA_STT_TERMINALS":""}`))
	cmd.SetOut(io.Discard)
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{stt.KeyLanguage, stt.KeyPasteMode, stt.KeyTerminals} {
		if got := get()[key]; got != defaults[key] {
			t.Errorf("reset %s = %q", key, got)
		}
	}
}

func TestConfigRefusesSTTProtectedKeysAndInvalidPasteMode(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	for _, input := range []string{
		`{"SENDA_STT_MODEL":"model"}`, `{"SENDA_STT_SHORTCUT":"ALT + a"}`,
		`{"SENDA_STT_PASTE_MODE":"invalid"}`, `{"SENDA_STT_PASTE_MODE":"PASTE"}`,
	} {
		cmd := configSetCmd()
		cmd.SetIn(strings.NewReader(input))
		cmd.SetOut(io.Discard)
		cmd.SetErr(io.Discard)
		if err := cmd.Execute(); err == nil {
			t.Fatalf("accepted %s", input)
		}
	}
	values, err := config.Load(paths.ConfigFile())
	if err != nil || len(values) != 0 {
		t.Fatalf("rejected writes changed config: %v, %v", values, err)
	}
}

func TestReadChangesRefusesOtherKeys(t *testing.T) {
	if _, err := readChanges(strings.NewReader(`{"DORLAB_API_KEY":"x"}`)); err == nil {
		t.Fatal("readChanges() accepted DORLAB_API_KEY")
	}
}

func TestReadChangesValidatesCoordinates(t *testing.T) {
	for _, input := range []string{`{"SENDA_WEATHER_LAT":"91"}`, `{"SENDA_WEATHER_LON":"-181"}`, `{"SENDA_WEATHER_LAT":"norte"}`} {
		if _, err := readChanges(strings.NewReader(input)); err == nil {
			t.Fatalf("readChanges(%s) accepted an invalid coordinate", input)
		}
	}
}

func TestReadChangesRejectsNonObjectJSON(t *testing.T) {
	if _, err := readChanges(strings.NewReader(`["SENDA_WEATHER_LAT"]`)); err == nil {
		t.Fatal("readChanges() accepted a JSON array")
	}
}

func TestReadChangesReturnsWhileStdinStaysOpen(t *testing.T) {
	reader, writer := io.Pipe()
	defer writer.Close()

	done := make(chan error, 1)
	go func() {
		_, err := readChanges(reader)
		done <- err
	}()

	if _, err := writer.Write([]byte(`{"SENDA_WEATHER_LAT":"39.4"}`)); err != nil {
		t.Fatal(err)
	}
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("readChanges() error = %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("readChanges() waited for EOF on stdin")
	}
}

func TestReadChangesValidatesFontScale(t *testing.T) {
	if _, err := readChanges(strings.NewReader(`{"SENDA_UI_FONT_SCALE":"110"}`)); err != nil {
		t.Fatalf("readChanges() rejected a valid scale: %v", err)
	}
	if _, err := readChanges(strings.NewReader(`{"SENDA_UI_FONT_SCALE":""}`)); err != nil {
		t.Fatalf("readChanges() rejected an empty scale, which restores the default: %v", err)
	}
	for _, input := range []string{`{"SENDA_UI_FONT_SCALE":"79"}`, `{"SENDA_UI_FONT_SCALE":"151"}`, `{"SENDA_UI_FONT_SCALE":"1.1"}`, `{"SENDA_UI_FONT_SCALE":"grande"}`} {
		if _, err := readChanges(strings.NewReader(input)); err == nil {
			t.Fatalf("readChanges(%s) accepted an invalid scale", input)
		}
	}
}

func TestConfigSTTPreload(t *testing.T) {
	if stt.LoadSettings(nil).Preload {
		t.Fatal("preload should default to false")
	}
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	for _, value := range []string{"", "true", "false", "true", ""} {
		cmd := configSetCmd()
		cmd.SetIn(strings.NewReader(`{"SENDA_STT_PRELOAD":"` + value + `"}`))
		cmd.SetOut(io.Discard)
		if err := cmd.Execute(); err != nil {
			t.Fatalf("set preload %q: %v", value, err)
		}
		values, err := config.Load(paths.ConfigFile())
		if err != nil {
			t.Fatal(err)
		}
		if got := values[stt.KeyPreload]; got != value {
			t.Fatalf("persisted preload = %q, want %q", got, value)
		}
		if got := stt.LoadSettings(values).Preload; got != (value == "true") {
			t.Fatalf("loaded preload = %v for %q", got, value)
		}
		cmd = configGetCmd()
		var out bytes.Buffer
		cmd.SetOut(&out)
		if err := cmd.Execute(); err != nil {
			t.Fatal(err)
		}
		var result struct {
			Values map[string]string `json:"values"`
		}
		if err := json.Unmarshal(out.Bytes(), &result); err != nil {
			t.Fatal(err)
		}
		want := value
		if want == "" {
			want = "false"
		}
		if got := result.Values[stt.KeyPreload]; got != want {
			t.Fatalf("get preload = %q, want %q", got, want)
		}
	}
}

func TestConfigRejectsInvalidSTTPreload(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	if err := config.Set(paths.ConfigFile(), map[string]string{stt.KeyPreload: "true"}); err != nil {
		t.Fatal(err)
	}
	for _, value := range []string{"yes", "1", "TRUE", "False", " true "} {
		cmd := configSetCmd()
		cmd.SetIn(strings.NewReader(`{"SENDA_STT_PRELOAD":"` + value + `"}`))
		cmd.SetOut(io.Discard)
		cmd.SetErr(io.Discard)
		if err := cmd.Execute(); err == nil {
			t.Fatalf("accepted preload %q", value)
		}
		values, err := config.Load(paths.ConfigFile())
		if err != nil || values[stt.KeyPreload] != "true" {
			t.Fatalf("rejected write changed config: %v, %v", values, err)
		}
	}
}
