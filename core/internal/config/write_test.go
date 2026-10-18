package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSetCreatesOwnerOnlyFileAndRoundTrips(t *testing.T) {
	path := filepath.Join(t.TempDir(), "senda", "config")

	if err := Set(path, map[string]string{
		"SENDA_WEATHER_LOCATION": "Valencia, España # ciudad",
		"SENDA_WEATHER_LAT":      "39.47",
	}); err != nil {
		t.Fatalf("Set() error = %v", err)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if mode := info.Mode().Perm(); mode != 0o600 {
		t.Fatalf("config mode = %04o, want 0600", mode)
	}

	values, err := Load(path)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if values["SENDA_WEATHER_LOCATION"] != "Valencia, España # ciudad" {
		t.Fatalf("location = %q", values["SENDA_WEATHER_LOCATION"])
	}
	if values["SENDA_WEATHER_LAT"] != "39.47" {
		t.Fatalf("lat = %q", values["SENDA_WEATHER_LAT"])
	}
}

func TestSetKeepsCommentsAndUnknownKeys(t *testing.T) {
	path := writeConfig(t, `# mi configuración
DORLAB_API_KEY=secret
SENDA_WEATHER_LAT=1.0
`)

	if err := Set(path, map[string]string{"SENDA_WEATHER_LAT": "2.5", "SENDA_WEATHER_LON": "-3.7"}); err != nil {
		t.Fatalf("Set() error = %v", err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, want := range []string{"# mi configuración", "DORLAB_API_KEY=secret", `SENDA_WEATHER_LAT="2.5"`, `SENDA_WEATHER_LON="-3.7"`} {
		if !strings.Contains(text, want) {
			t.Fatalf("config = %q, missing %q", text, want)
		}
	}
	if strings.Count(text, "SENDA_WEATHER_LAT") != 1 {
		t.Fatalf("SENDA_WEATHER_LAT written more than once: %q", text)
	}
}

func TestSetEmptyValueRemovesKey(t *testing.T) {
	path := writeConfig(t, "SENDA_GOOGLE_CALENDARS=a,b\nDORLAB_API_KEY=secret\n")

	if err := Set(path, map[string]string{"SENDA_GOOGLE_CALENDARS": ""}); err != nil {
		t.Fatalf("Set() error = %v", err)
	}

	values, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := values["SENDA_GOOGLE_CALENDARS"]; ok {
		t.Fatalf("key still present: %v", values)
	}
	if values["DORLAB_API_KEY"] != "secret" {
		t.Fatalf("unrelated key lost: %v", values)
	}
}

func TestSetRejectsInvalidFileWithoutOverwriting(t *testing.T) {
	original := "this line has no equals sign\n"
	path := writeConfig(t, original)

	if err := Set(path, map[string]string{"SENDA_WEATHER_LAT": "1"}); err == nil {
		t.Fatal("Set() rewrote an invalid config file")
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != original {
		t.Fatalf("invalid file was modified: %q", data)
	}
}

func TestSetRejectsInvalidKeyName(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config")

	if err := Set(path, map[string]string{"bad key\nEVIL": "x"}); err == nil {
		t.Fatal("Set() accepted an invalid key name")
	}
}

func TestSetKeepsValueWithNewlineInsideQuotes(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config")

	if err := Set(path, map[string]string{"SENDA_WEATHER_LOCATION": "linea\nnueva"}); err != nil {
		t.Fatalf("Set() error = %v", err)
	}

	values, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if values["SENDA_WEATHER_LOCATION"] != "linea\nnueva" {
		t.Fatalf("value = %q, want the newline preserved", values["SENDA_WEATHER_LOCATION"])
	}
}
