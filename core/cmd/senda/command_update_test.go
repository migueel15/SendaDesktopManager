package main

import "testing"

func TestAvailableUpdate(t *testing.T) {
	cases := []struct {
		name    string
		current string
		latest  string
		want    bool
	}{
		{"newer release", "v0.1.0", "v0.2.0", true},
		{"same release", "v0.2.0", "v0.2.0", false},
		{"development build never updates", "dev", "v0.2.0", false},
		{"no release found", "v0.1.0", "", false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := availableUpdate(tc.current, tc.latest); got != tc.want {
				t.Fatalf("availableUpdate(%q, %q) = %v, want %v", tc.current, tc.latest, got, tc.want)
			}
		})
	}
}
