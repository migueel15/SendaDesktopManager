package location

import "testing"

func TestZoneFromPathReadsIANAName(t *testing.T) {
	cases := map[string]string{
		"/usr/share/zoneinfo/Europe/Madrid":                  "Europe/Madrid",
		"/usr/share/zoneinfo/America/Argentina/Buenos_Aires": "America/Argentina/Buenos_Aires",
		"/etc/UTC":                                           "",
	}
	for path, want := range cases {
		if got := zoneFromPath(path); got != want {
			t.Fatalf("zoneFromPath(%q) = %q, want %q", path, got, want)
		}
	}
}

func TestDefaultForZoneKnownAndUnknown(t *testing.T) {
	place, ok := DefaultForZone("Europe/Madrid")
	if !ok || place.Name != "Madrid" {
		t.Fatalf("DefaultForZone(Europe/Madrid) = %+v, %v", place, ok)
	}
	if _, ok := DefaultForZone("UTC"); ok {
		t.Fatal("DefaultForZone(UTC) returned a place; UTC does not identify a country")
	}
}
