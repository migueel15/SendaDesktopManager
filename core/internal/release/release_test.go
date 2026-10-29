package release

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRejectsNonHTTPSURLs(t *testing.T) {
	ctx := context.Background()
	if _, err := LatestTagForChannel(ctx, "http://example.com", false); err == nil {
		t.Error("LatestTag() accepted plain http to a remote host")
	}
	if _, err := LatestTagForChannel(ctx, "http://127.0.0.1.example.com", false); err == nil {
		t.Error("LatestTag() accepted a loopback-prefixed host name")
	}
	if err := Download(ctx, "ftp://127.0.0.1/file", filepath.Join(t.TempDir(), "f")); err == nil {
		t.Error("Download() accepted ftp scheme")
	}
}

func TestDownloadWritesBody(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("payload"))
	}))
	defer srv.Close()

	dst := filepath.Join(t.TempDir(), "asset")
	if err := Download(context.Background(), srv.URL+"/asset", dst); err != nil {
		t.Fatalf("Download() error = %v", err)
	}
	got, err := os.ReadFile(dst)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "payload" {
		t.Fatalf("downloaded content = %q, want %q", got, "payload")
	}
}

func TestDownloadRejectsNon200(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.NotFound(w, r)
	}))
	defer srv.Close()

	if err := Download(context.Background(), srv.URL, filepath.Join(t.TempDir(), "asset")); err == nil {
		t.Fatal("Download() succeeded on HTTP 404")
	}
}

func TestVerifyChecksum(t *testing.T) {
	dir := t.TempDir()
	asset := filepath.Join(dir, "senda-v1.0.0-linux-amd64")
	content := []byte("binary contents")
	if err := os.WriteFile(asset, content, 0o600); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(content)
	hash := hex.EncodeToString(sum[:])

	checksums := filepath.Join(dir, "checksums.txt")
	other := strings.Repeat("0", 64)
	writeChecksums(t, checksums,
		other+"  senda-quickshell-v1.0.0.tar.gz\n"+
			hash+"  senda-v1.0.0-linux-amd64\n")

	if err := VerifyChecksum(checksums, "senda-v1.0.0-linux-amd64", asset); err != nil {
		t.Fatalf("VerifyChecksum() match error = %v", err)
	}

	// Uppercase digests and the sha256sum binary-mode '*' marker are accepted.
	writeChecksums(t, checksums, strings.ToUpper(hash)+" *senda-v1.0.0-linux-amd64\n")
	if err := VerifyChecksum(checksums, "senda-v1.0.0-linux-amd64", asset); err != nil {
		t.Fatalf("VerifyChecksum() uppercase/binary-marker error = %v", err)
	}

	writeChecksums(t, checksums, other+"  senda-v1.0.0-linux-amd64\n")
	if err := VerifyChecksum(checksums, "senda-v1.0.0-linux-amd64", asset); err == nil {
		t.Fatal("VerifyChecksum() accepted a mismatched digest")
	}

	if err := VerifyChecksum(checksums, "senda-v9.9.9-linux-amd64", asset); err == nil {
		t.Fatal("VerifyChecksum() accepted an asset missing from checksums.txt")
	}
}

func writeChecksums(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}

// tarEntry describes one entry for buildArchive.
type tarEntry struct {
	name     string
	typeflag byte
	body     string
	linkname string
}

func buildArchive(t *testing.T, entries []tarEntry) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "data.tar.gz")
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()

	gz := gzip.NewWriter(f)
	tw := tar.NewWriter(gz)
	for _, e := range entries {
		hdr := &tar.Header{
			Name:     e.name,
			Typeflag: e.typeflag,
			Linkname: e.linkname,
			Mode:     0o755,
			Size:     int64(len(e.body)),
		}
		if e.typeflag == tar.TypeDir || e.typeflag == tar.TypeSymlink || e.typeflag == tar.TypeLink {
			hdr.Size = 0
		}
		if err := tw.WriteHeader(hdr); err != nil {
			t.Fatal(err)
		}
		if hdr.Size > 0 {
			if _, err := tw.Write([]byte(e.body)); err != nil {
				t.Fatal(err)
			}
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

func TestExtractDataTarballAcceptsValidArchive(t *testing.T) {
	archive := buildArchive(t, []tarEntry{
		{name: "quickshell/", typeflag: tar.TypeDir},
		{name: "quickshell/shell.qml", typeflag: tar.TypeReg, body: "import QtQuick"},
		{name: "scripts/", typeflag: tar.TypeDir},
		{name: "scripts/discord-bridge.py", typeflag: tar.TypeReg, body: "print(1)"},
		{name: "version", typeflag: tar.TypeReg, body: "v1.0.0"},
	})
	dst := t.TempDir()

	if err := ExtractDataTarball(archive, dst); err != nil {
		t.Fatalf("ExtractDataTarball() error = %v", err)
	}

	for rel, want := range map[string]string{
		"quickshell/shell.qml":      "import QtQuick",
		"scripts/discord-bridge.py": "print(1)",
		"version":                   "v1.0.0",
	} {
		got, err := os.ReadFile(filepath.Join(dst, filepath.FromSlash(rel)))
		if err != nil {
			t.Fatalf("missing %s: %v", rel, err)
		}
		if string(got) != want {
			t.Fatalf("%s = %q, want %q", rel, got, want)
		}
	}

	info, err := os.Stat(filepath.Join(dst, "version"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o644 {
		t.Fatalf("version mode = %v, want 0644", info.Mode().Perm())
	}
}

func TestExtractDataTarballRejectsUnsafeEntries(t *testing.T) {
	cases := map[string][]tarEntry{
		"parent traversal": {
			{name: "../evil", typeflag: tar.TypeReg, body: "x"},
		},
		"nested traversal": {
			{name: "quickshell/../../evil", typeflag: tar.TypeReg, body: "x"},
		},
		"absolute path": {
			{name: "/etc/evil", typeflag: tar.TypeReg, body: "x"},
		},
		"symlink": {
			{name: "quickshell/link", typeflag: tar.TypeSymlink, linkname: "/etc/passwd"},
		},
		"hard link": {
			{name: "quickshell/hard", typeflag: tar.TypeLink, linkname: "version"},
		},
		"unknown prefix": {
			{name: "bin/senda", typeflag: tar.TypeReg, body: "x"},
		},
		"version as directory": {
			{name: "version/", typeflag: tar.TypeDir},
		},
	}

	for name, entries := range cases {
		t.Run(name, func(t *testing.T) {
			archive := buildArchive(t, entries)
			dst := filepath.Join(t.TempDir(), "stage")
			if err := os.MkdirAll(dst, 0o755); err != nil {
				t.Fatal(err)
			}
			if err := ExtractDataTarball(archive, dst); err == nil {
				t.Fatal("ExtractDataTarball() accepted an unsafe entry")
			}
		})
	}
}

func TestReplaceFileAtomic(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "new")
	dst := filepath.Join(dir, "senda")
	if err := os.WriteFile(src, []byte("new binary"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(dst, []byte("old binary"), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := ReplaceFileAtomic(src, dst, 0o755); err != nil {
		t.Fatalf("ReplaceFileAtomic() error = %v", err)
	}

	got, err := os.ReadFile(dst)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "new binary" {
		t.Fatalf("dst content = %q, want new binary", got)
	}
	info, err := os.Stat(dst)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o755 {
		t.Fatalf("dst mode = %v, want 0755", info.Mode().Perm())
	}

	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 2 {
		t.Fatalf("directory has %d entries, want 2 (src and dst only, no temporary leftovers)", len(entries))
	}
}
