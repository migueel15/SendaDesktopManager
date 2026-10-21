package models

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestRejectsUnsafeArchiveEntries(t *testing.T) {
	cases := map[string]string{
		"parent":        "QlpoOTFBWSZTWfEOLiAAAFt7gMmAAADAAc+AAQB2IJ4ACAggAFQ0gnpMBGRpjUEkoyDJkDTQN/SBchBRyEIv7niTg/BAhgYjIk7VkPYQssgusezsZqHuk+z5vLTRqtpEiID8XckU4UJDxDi4gA==",
		"nested-parent": "QlpoOTFBWSZTWfyh8NEAAHF9gMmAAADAAe2AAAF+YJ4ACAggAFQykxDRoD0JpptQSSh6g0MgaAH04FCEE6kIRT1KwlB60CGBiJE4Yk6T6YAhGkdt62R7mCn01StqWvN4grmXXckgfi7kinChIflD4aI=",
		"symlink":       "QlpoOTFBWSZTWVC3TcAAAHB7gMiAABBAAfcACIAubZ4AAAggAFQyiGmgaZPUHqNpBJKGQD0gNAH2s6BILqkIQ/crC0jFAhgYk7qbQFBhCPIfSmnEhfAsk1VW+qkHVGdsXNaRJA/F3JFOFCQULdNwAA==",
	}
	for name, encoded := range cases {
		t.Run(name, func(t *testing.T) {
			data, err := base64.StdEncoding.DecodeString(encoded)
			if err != nil {
				t.Fatal(err)
			}
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write(data) }))
			defer server.Close()
			sum := sha256.Sum256(data)
			dir := t.TempDir()
			store := &Store{Dir: dir, Client: server.Client(), Catalog: []Entry{{ID: "bad", Archive: "arch", URL: server.URL, SHA256: hex.EncodeToString(sum[:]), SizeBytes: int64(len(data))}}}
			if err := store.Install(context.Background(), "bad", nil); err == nil {
				t.Fatal("unsafe archive accepted")
			}
			if store.Installed("bad") {
				t.Fatal("unsafe archive installed")
			}
			entries, err := os.ReadDir(dir)
			if err != nil {
				t.Fatal(err)
			}
			if len(entries) != 0 {
				t.Fatalf("temporary files left behind: %v", entries)
			}
			if _, err := os.Stat(filepath.Join(dir, "outside")); !errors.Is(err, os.ErrNotExist) {
				t.Fatalf("outside file: %v", err)
			}
		})
	}
}

func TestInstallCancellationCleansUp(t *testing.T) {
	data, err := base64.StdEncoding.DecodeString(testArchive)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write(data) }))
	defer server.Close()
	sum := sha256.Sum256(data)
	dir := t.TempDir()
	store := &Store{Dir: dir, Client: server.Client(), Catalog: []Entry{{ID: "tiny", Archive: "arch", URL: server.URL, SHA256: hex.EncodeToString(sum[:]), SizeBytes: int64(len(data))}}}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	err = store.Install(ctx, "tiny", func(int64, int64) { cancel() })
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("Install = %v", err)
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 0 {
		t.Fatalf("temporary files left behind: %v", entries)
	}
}

func TestInstalledRequiresValidManifestAndFiles(t *testing.T) {
	store, entry := fixture(t, "")
	dir := store.ModelDir(entry.ID)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if store.Installed(entry.ID) {
		t.Fatal("directory without manifest reported installed")
	}
	for _, name := range []string{entry.Files.Encoder, entry.Files.Decoder, entry.Files.Joiner, entry.Files.Tokens} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("x"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "manifest.json"), []byte(`{"id":"tiny","kind":"transducer"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if store.Installed(entry.ID) {
		t.Fatal("manifest without file references reported installed")
	}
}
