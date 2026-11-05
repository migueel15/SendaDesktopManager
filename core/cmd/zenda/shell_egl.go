package main

import (
	"os"
	"path/filepath"
	"strings"
)

const (
	eglVendorEnv  = "__EGL_VENDOR_LIBRARY_FILENAMES"
	nvidiaPCIID   = "0x10de"
	drmClassDir   = "/sys/class/drm"
	nvidiaEGLFile = "10_nvidia.json"
)

var eglVendorDirs = []string{"/etc/glvnd/egl_vendor.d", "/usr/share/glvnd/egl_vendor.d"}

// nvidiaOnlyEGLEnv limits Quickshell to the NVIDIA EGL vendor when every
// connected output is driven by an NVIDIA GPU. Otherwise libglvnd also loads
// Mesa, with its LLVM backend, for an integrated GPU that draws no screen.
// It returns nothing when the variable is already set, when an output is on
// another GPU, or when the NVIDIA vendor file is missing.
func nvidiaOnlyEGLEnv() []string {
	if _, set := os.LookupEnv(eglVendorEnv); set {
		return nil
	}
	if !allOutputsOnNvidia(drmClassDir) {
		return nil
	}
	file := findEGLVendorFile(eglVendorDirs, nvidiaEGLFile)
	if file == "" {
		return nil
	}
	return []string{eglVendorEnv + "=" + file}
}

// allOutputsOnNvidia reports whether drmDir lists at least one connected
// connector and all of them belong to cards with the NVIDIA PCI vendor ID.
func allOutputsOnNvidia(drmDir string) bool {
	connectors, err := filepath.Glob(filepath.Join(drmDir, "card*-*"))
	if err != nil {
		return false
	}
	connected := 0
	for _, connector := range connectors {
		status, err := os.ReadFile(filepath.Join(connector, "status"))
		if err != nil || strings.TrimSpace(string(status)) != "connected" {
			continue
		}
		connected++
		card, _, _ := strings.Cut(filepath.Base(connector), "-")
		vendor, err := os.ReadFile(filepath.Join(drmDir, card, "device", "vendor"))
		if err != nil || strings.TrimSpace(string(vendor)) != nvidiaPCIID {
			return false
		}
	}
	return connected > 0
}

func findEGLVendorFile(dirs []string, name string) string {
	for _, dir := range dirs {
		path := filepath.Join(dir, name)
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			return path
		}
	}
	return ""
}
