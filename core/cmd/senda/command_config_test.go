package main

import (
	"strings"
	"testing"
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
