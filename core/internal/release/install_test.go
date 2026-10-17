package release

import (
	"archive/tar"
	"compress/gzip"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"testing"
)

// installTarball builds a Quickshell-style tarball with the given regular
// files. The managed directories are always added so the archive is valid.
func installTarball(t *testing.T, files map[string]string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "senda-quickshell.tar.gz")
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()

	gz := gzip.NewWriter(f)
	tw := tar.NewWriter(gz)
	for _, dir := range []string{"quickshell/", "scripts/"} {
		if err := tw.WriteHeader(&tar.Header{Name: dir, Typeflag: tar.TypeDir, Mode: 0o755}); err != nil {
			t.Fatal(err)
		}
	}
	for name, body := range files {
		hdr := &tar.Header{Name: name, Typeflag: tar.TypeReg, Mode: 0o644, Size: int64(len(body))}
		if err := tw.WriteHeader(hdr); err != nil {
			t.Fatal(err)
		}
		if _, err := tw.Write([]byte(body)); err != nil {
			t.Fatal(err)
		}
	}
	if err := tw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gz.Close(); err != nil {
		t.Fatal(err)
	}
	return path
}

// listDir returns the sorted names inside dir.
func listDir(t *testing.T, dir string) []string {
	t.Helper()
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)
	return names
}

func TestInstallDataReplacesPreviousInstall(t *testing.T) {
	parent := t.TempDir()
	dataDir := filepath.Join(parent, "senda")

	first := installTarball(t, map[string]string{
		"version":                 "v1.0.0\n",
		"quickshell/shell.qml":    "first",
		"quickshell/only-old.qml": "old",
		"scripts/bridge.py":       "first",
	})
	if err := InstallData(first, dataDir); err != nil {
		t.Fatalf("first InstallData() error = %v", err)
	}

	second := installTarball(t, map[string]string{
		"version":              "v2.0.0\n",
		"quickshell/shell.qml": "second",
		"scripts/bridge.py":    "second",
	})
	if err := InstallData(second, dataDir); err != nil {
		t.Fatalf("second InstallData() error = %v", err)
	}

	version, err := os.ReadFile(filepath.Join(dataDir, "version"))
	if err != nil || string(version) != "v2.0.0\n" {
		t.Fatalf("version = %q, %v; want v2.0.0", version, err)
	}
	shell, err := os.ReadFile(filepath.Join(dataDir, "quickshell", "shell.qml"))
	if err != nil || string(shell) != "second" {
		t.Fatalf("shell.qml = %q, %v; want second", shell, err)
	}
	if _, err := os.Stat(filepath.Join(dataDir, "quickshell", "only-old.qml")); !os.IsNotExist(err) {
		t.Fatalf("file from the first install survived: %v", err)
	}

	if got := listDir(t, parent); !reflect.DeepEqual(got, []string{"senda"}) {
		t.Errorf("parent entries = %v, want only senda (no staging or .old left)", got)
	}
	if got := listDir(t, dataDir); !reflect.DeepEqual(got, []string{"quickshell", "scripts", "version"}) {
		t.Errorf("data entries = %v, want the managed entries only", got)
	}
}

func TestInstallDataRejectsMissingEntryAndKeepsPreviousInstall(t *testing.T) {
	parent := t.TempDir()
	dataDir := filepath.Join(parent, "senda")

	good := installTarball(t, map[string]string{
		"version":              "v1.0.0\n",
		"quickshell/shell.qml": "good",
	})
	if err := InstallData(good, dataDir); err != nil {
		t.Fatalf("InstallData() error = %v", err)
	}

	// This archive has no version file, so the install must be refused.
	broken := installTarball(t, map[string]string{
		"quickshell/shell.qml": "broken",
	})
	if err := InstallData(broken, dataDir); err == nil {
		t.Fatal("InstallData() accepted an archive without version")
	}

	shell, err := os.ReadFile(filepath.Join(dataDir, "quickshell", "shell.qml"))
	if err != nil || string(shell) != "good" {
		t.Fatalf("previous install changed: %q, %v", shell, err)
	}
	if got := listDir(t, parent); !reflect.DeepEqual(got, []string{"senda"}) {
		t.Errorf("parent entries = %v, want only senda", got)
	}
}
