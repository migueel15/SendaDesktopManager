package main

import (
	"io"
	"strings"
	"testing"
	"time"
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
