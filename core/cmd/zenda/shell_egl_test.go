package main

import (
	"os"
	"path/filepath"
	"testing"
)

// fakeDRM builds a /sys/class/drm-like tree: cards maps a card name to its
// PCI vendor ID, and connectors maps a connector name to its status.
func fakeDRM(t *testing.T, cards map[string]string, connectors map[string]string) string {
	t.Helper()
	dir := t.TempDir()
	for card, vendor := range cards {
		device := filepath.Join(dir, card, "device")
		if err := os.MkdirAll(device, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(device, "vendor"), []byte(vendor+"\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	for connector, status := range connectors {
		path := filepath.Join(dir, connector)
		if err := os.MkdirAll(path, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(path, "status"), []byte(status+"\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func TestAllOutputsOnNvidia(t *testing.T) {
	cards := map[string]string{"card1": "0x1002", "card2": nvidiaPCIID}
	tests := []struct {
		name       string
		connectors map[string]string
		want       bool
	}{
		{"connected outputs only on nvidia", map[string]string{
			"card1-DP-1": "disconnected", "card2-DP-3": "connected", "card2-DP-4": "connected",
		}, true},
		{"one output on the integrated gpu", map[string]string{
			"card1-eDP-1": "connected", "card2-DP-3": "connected",
		}, false},
		{"no connected outputs", map[string]string{"card2-DP-3": "disconnected"}, false},
		{"connector of an unknown card", map[string]string{"card9-DP-1": "connected"}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := allOutputsOnNvidia(fakeDRM(t, cards, tt.connectors)); got != tt.want {
				t.Fatalf("allOutputsOnNvidia() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestFindEGLVendorFile(t *testing.T) {
	first, second := t.TempDir(), t.TempDir()
	if got := findEGLVendorFile([]string{first, second}, nvidiaEGLFile); got != "" {
		t.Fatalf("findEGLVendorFile() = %q, want empty", got)
	}
	want := filepath.Join(second, nvidiaEGLFile)
	if err := os.WriteFile(want, []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := findEGLVendorFile([]string{first, second}, nvidiaEGLFile); got != want {
		t.Fatalf("findEGLVendorFile() = %q, want %q", got, want)
	}
}

func TestNvidiaOnlyEGLEnvKeepsUserValue(t *testing.T) {
	t.Setenv(eglVendorEnv, "/custom.json")
	if got := nvidiaOnlyEGLEnv(); got != nil {
		t.Fatalf("nvidiaOnlyEGLEnv() = %v, want nil", got)
	}
}
