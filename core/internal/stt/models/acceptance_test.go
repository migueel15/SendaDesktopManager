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
	"regexp"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// testArchive is a tiny .tar.bz2 (Go cannot create bzip2) with a top-level
// directory "arch" holding encoder.int8.onnx, decoder.int8.onnx,
// joiner.int8.onnx and tokens.txt.
const testArchive = "QlpoOTFBWSZTWeykVTwAAPv/hMmQIEBAAf/AABggCG55nkAAAIA4MAD4yGAGTTQZDBDTEaMCSmmkyIAAANAwgikSnqe0Q0aEBtAAaZdk8MZs+EM0+At44zFIoCjh9a6bUu0CVJpq2taUE2JCgSAIGSdkkG+JP69+aVhSwElACY4m/hcCX4cEshICaVJammetNzBlSQO7ooFMzujdXXN0QRYDyRCp7Jc1AReyO+Ji/2/khmjbgXEY4RJWoqLlOcaHxkzKamYF9HMJYJzSjCak8pbklaeoSb1S+7JKnPaoHsXckU4UJDspFU8A"

func fixture(t *testing.T, sha string) (*Store, Entry) {
	t.Helper()
	data, err := base64.StdEncoding.DecodeString(testArchive)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Write(data)
	}))
	t.Cleanup(server.Close)
	if sha == "" {
		sum := sha256.Sum256(data)
		sha = hex.EncodeToString(sum[:])
	}
	entry := Entry{
		ID: "tiny", Name: "Tiny", Archive: "arch", URL: server.URL + "/arch.tar.bz2", SHA256: sha,
		SizeBytes: int64(len(data)), Languages: []string{"es"},
		Files: ModelFiles{Encoder: "encoder.int8.onnx", Decoder: "decoder.int8.onnx", Joiner: "joiner.int8.onnx", Tokens: "tokens.txt"},
	}
	store := &Store{Dir: t.TempDir(), Catalog: []Entry{entry}, Client: server.Client()}
	return store, entry
}

func TestAC6InstallDownloadsVerifiesAndWritesManifest(t *testing.T) {
	store, _ := fixture(t, "")
	var last, total, calls int64
	increasing := true
	err := store.Install(context.Background(), "tiny", func(done, size int64) {
		if done < last {
			increasing = false
		}
		last, total = done, size
		calls++
	})
	if err != nil {
		t.Fatalf("Install = %v", err)
	}
	if calls == 0 || !increasing || last != total || total <= 0 {
		t.Fatalf("progress calls=%d increasing=%v last=%d total=%d", calls, increasing, last, total)
	}
	if !store.Installed("tiny") {
		t.Fatal("Installed = false")
	}
	dir := store.ModelDir("tiny")
	if dir == "" {
		t.Fatal("ModelDir empty")
	}
	m, err := stt.ReadManifest(dir)
	if err != nil {
		t.Fatalf("ReadManifest = %v", err)
	}
	if m.ID != "tiny" || m.Kind != "transducer" {
		t.Fatalf("manifest = %+v", m)
	}
	for _, name := range []string{m.Encoder, m.Decoder, m.Joiner, m.Tokens} {
		if name == "" {
			t.Fatalf("manifest has empty path: %+v", m)
		}
		path := name
		if !filepath.IsAbs(path) {
			path = filepath.Join(dir, name)
		}
		if _, err := os.Stat(path); err != nil {
			t.Errorf("manifest path %q: %v", name, err)
		}
	}
}

func TestAC6ListMarksActive(t *testing.T) {
	store, _ := fixture(t, "")
	list, err := store.List("tiny")
	if err != nil {
		t.Fatalf("List = %v", err)
	}
	if len(list) != 1 || list[0].ID != "tiny" || !list[0].Active {
		t.Fatalf("List = %+v", list)
	}
	list, err = store.List("other")
	if err != nil || len(list) != 1 || list[0].Active {
		t.Fatalf("List(other) = %+v, %v", list, err)
	}
}

func TestAC6ChecksumMismatchInstallsNothing(t *testing.T) {
	store, _ := fixture(t, strings.Repeat("0", 64))
	err := store.Install(context.Background(), "tiny", func(int64, int64) {})
	if !errors.Is(err, ErrChecksum) {
		t.Fatalf("Install = %v, want ErrChecksum", err)
	}
	if store.Installed("tiny") {
		t.Fatal("model reported installed")
	}
	if dir := store.ModelDir("tiny"); dir != "" {
		if _, err := os.Stat(dir); !os.IsNotExist(err) {
			t.Fatalf("model directory left behind: %v", err)
		}
	}
	entries, err := os.ReadDir(store.Dir)
	if err != nil && !os.IsNotExist(err) {
		t.Fatalf("ReadDir(%s) = %v", store.Dir, err)
	}
	for _, e := range entries {
		t.Errorf("leftover after checksum failure: %s", filepath.Join(store.Dir, e.Name()))
	}
}

func TestAC6UnknownModel(t *testing.T) {
	store, _ := fixture(t, "")
	if err := store.Install(context.Background(), "nope", nil); !errors.Is(err, ErrUnknownModel) {
		t.Fatalf("Install = %v, want ErrUnknownModel", err)
	}
}

func TestAC6RemoveDeletesDirectory(t *testing.T) {
	store, _ := fixture(t, "")
	if err := store.Install(context.Background(), "tiny", func(int64, int64) {}); err != nil {
		t.Fatalf("Install = %v", err)
	}
	dir := store.ModelDir("tiny")
	if err := store.Remove("tiny"); err != nil {
		t.Fatalf("Remove = %v", err)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatalf("directory still exists: %v", err)
	}
	if store.Installed("tiny") {
		t.Fatal("still installed")
	}
}

func TestAC6CatalogDefaultEntry(t *testing.T) {
	for _, e := range Catalog() {
		if e.ID != stt.DefaultModelID {
			continue
		}
		if !regexp.MustCompile("^[0-9a-f]{64}$").MatchString(e.SHA256) || !strings.HasPrefix(e.URL, "https://") {
			t.Fatalf("entry = %+v", e)
		}
		return
	}
	t.Fatalf("catalog has no %s", stt.DefaultModelID)
}
