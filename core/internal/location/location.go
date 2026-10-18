// Package location picks a default weather location from the system time zone,
// so the dashboard can show the weather before the user chooses a place.
package location

import (
	"path/filepath"
	"strings"
)

// Place is a named point used for weather lookups.
type Place struct {
	Name      string
	Latitude  float64
	Longitude float64
}

const zoneinfoMarker = "zoneinfo/"

// capitals maps IANA time zones to the capital of the country they cover. A
// zone shared by several countries uses the most populous one.
var capitals = map[string]Place{
	"Europe/Madrid":                  {Name: "Madrid", Latitude: 40.4168, Longitude: -3.7038},
	"Atlantic/Canary":                {Name: "Madrid", Latitude: 40.4168, Longitude: -3.7038},
	"Europe/Lisbon":                  {Name: "Lisboa", Latitude: 38.7223, Longitude: -9.1393},
	"Europe/Paris":                   {Name: "París", Latitude: 48.8566, Longitude: 2.3522},
	"Europe/London":                  {Name: "Londres", Latitude: 51.5072, Longitude: -0.1276},
	"Europe/Dublin":                  {Name: "Dublín", Latitude: 53.3498, Longitude: -6.2603},
	"Europe/Berlin":                  {Name: "Berlín", Latitude: 52.52, Longitude: 13.405},
	"Europe/Rome":                    {Name: "Roma", Latitude: 41.9028, Longitude: 12.4964},
	"Europe/Amsterdam":               {Name: "Ámsterdam", Latitude: 52.3676, Longitude: 4.9041},
	"Europe/Brussels":                {Name: "Bruselas", Latitude: 50.8503, Longitude: 4.3517},
	"America/New_York":               {Name: "Washington", Latitude: 38.9072, Longitude: -77.0369},
	"America/Mexico_City":            {Name: "Ciudad de México", Latitude: 19.4326, Longitude: -99.1332},
	"America/Bogota":                 {Name: "Bogotá", Latitude: 4.711, Longitude: -74.0721},
	"America/Lima":                   {Name: "Lima", Latitude: -12.0464, Longitude: -77.0428},
	"America/Santiago":               {Name: "Santiago", Latitude: -33.4489, Longitude: -70.6693},
	"America/Caracas":                {Name: "Caracas", Latitude: 10.4806, Longitude: -66.9036},
	"America/Argentina/Buenos_Aires": {Name: "Buenos Aires", Latitude: -34.6037, Longitude: -58.3816},
}

// SystemTimeZone returns the IANA name of the system time zone, such as
// Europe/Madrid, or "" when it cannot be read.
func SystemTimeZone() string {
	target, err := filepath.EvalSymlinks("/etc/localtime")
	if err != nil {
		return ""
	}
	return zoneFromPath(target)
}

// zoneFromPath extracts the IANA name from a path under zoneinfo.
func zoneFromPath(path string) string {
	index := strings.Index(path, zoneinfoMarker)
	if index < 0 {
		return ""
	}
	return path[index+len(zoneinfoMarker):]
}

// DefaultForZone returns the capital for an IANA time zone, if it is known.
func DefaultForZone(zone string) (Place, bool) {
	place, ok := capitals[zone]
	return place, ok
}

// Default returns the capital for the system time zone, if it is known.
func Default() (Place, bool) {
	return DefaultForZone(SystemTimeZone())
}
