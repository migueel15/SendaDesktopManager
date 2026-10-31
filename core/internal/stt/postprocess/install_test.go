package postprocess

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func runtimeArchive(t *testing.T, extra ...tar.Header) []byte {
	t.Helper()
	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	tw := tar.NewWriter(gz)
	data := "#!/bin/sh\nexit 0\n"
	entries := []tar.Header{{Name: "fixture", Typeflag: tar.TypeDir, Mode: 0700},
		{Name: "fixture/llama-completion", Typeflag: tar.TypeReg, Mode: 0700, Size: int64(len(data))},
		{Name: "fixture/libggml.so.0", Typeflag: tar.TypeReg, Mode: 0600, Size: 0},
		{Name: "fixture/libggml.so", Typeflag: tar.TypeSymlink, Linkname: "libggml.so.0"}}
	entries = append(entries, extra...)
	for _, h := range entries {
		if err := tw.WriteHeader(&h); err != nil {
			t.Fatal(err)
		}
		if h.Size > 0 {
			if _, err := tw.Write([]byte(data)); err != nil {
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
	return b.Bytes()
}

func testArtifact(url string, data []byte) Artifact {
	hash := sha256.Sum256(data)
	return Artifact{URL: url, Size: int64(len(data)), SHA256: hex.EncodeToString(hash[:])}
}

func fixtureStore(t *testing.T) (*Store, *atomic.Int32) {
	t.Helper()
	archive, model := runtimeArchive(t), []byte("GGUFfixture-model")
	var requests atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		switch r.URL.Path {
		case "/runtime":
			w.Write(archive)
		case "/model":
			w.Write(model)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(server.Close)
	s := NewStore(filepath.Join(t.TempDir(), "postprocess"))
	s.Supported = true
	s.ArchiveRoot = "fixture"
	s.Client = server.Client()
	s.Runtime, s.Model = testArtifact(server.URL+"/runtime", archive), testArtifact(server.URL+"/model", model)
	return s, &requests
}

func TestManagedInstallAndReadiness(t *testing.T) {
	s, requests := fixtureStore(t)
	if s.Status(context.Background()).Ready {
		t.Fatal("missing bundle is ready")
	}
	var phases []string
	var last int64
	err := s.Install(context.Background(), func(phase string, done, total int64) {
		if done < last || done > total {
			t.Errorf("invalid progress %d/%d after %d", done, total, last)
		}
		last = done
		phases = append(phases, phase)
	})
	if err != nil {
		t.Fatal(err)
	}
	if !s.Status(context.Background()).Ready || last != s.Runtime.Size+s.Model.Size || len(phases) < 2 {
		t.Fatal("bundle/progress not ready", phases, last)
	}
	if err := s.Install(context.Background(), nil); err != nil {
		t.Fatal(err)
	}
	if requests.Load() != 2 {
		t.Fatal("redownloaded ready bundle", requests.Load())
	}
	if _, err := os.Stat(filepath.Join(s.Dir, "runtime.tar.gz")); !os.IsNotExist(err) {
		t.Fatal("kept archive")
	}
	if err := os.Remove(s.ModelPath()); err != nil {
		t.Fatal(err)
	}
	if s.Status(context.Background()).Ready {
		t.Fatal("missing model still ready")
	}
}

func TestInstallFailuresPreservePreviousBundle(t *testing.T) {
	for _, mode := range []string{"hash", "size", "http", "runtime", "cancelled", "unsupported"} {
		t.Run(mode, func(t *testing.T) {
			s, _ := fixtureStore(t)
			if err := os.MkdirAll(s.Dir, 0700); err != nil {
				t.Fatal(err)
			}
			sentinel := filepath.Join(s.Dir, "previous")
			if err := os.WriteFile(sentinel, []byte("preserve"), 0600); err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			switch mode {
			case "hash":
				s.Model.SHA256 = strings.Repeat("0", 64)
			case "size":
				s.Model.Size--
			case "http":
				s.Model.URL += "-missing"
			case "runtime":
				s.CheckRuntime = func(context.Context, string) error { return fmt.Errorf("not executable") }
			case "cancelled":
				cancel()
			case "unsupported":
				s.Supported = false
			}
			if err := s.Install(ctx, nil); err == nil {
				t.Fatal("expected error")
			}
			if b, err := os.ReadFile(sentinel); err != nil || string(b) != "preserve" {
				t.Fatal("lost previous installation", err)
			}
			entries, err := os.ReadDir(filepath.Dir(s.Dir))
			if err != nil {
				t.Fatal(err)
			}
			if len(entries) != 1 {
				t.Fatal("left staging files", entries)
			}
		})
	}
}

func TestCancelDownloadAndRetry(t *testing.T) {
	s, _ := fixtureStore(t)
	ctx, cancel := context.WithCancel(context.Background())
	err := s.Install(ctx, func(phase string, done, total int64) {
		if phase == "Descargando modelo" {
			cancel()
		}
	})
	if err == nil {
		t.Fatal("cancelled install succeeded")
	}
	if s.Status(context.Background()).Ready {
		t.Fatal("partial install ready")
	}
	if err := s.Install(context.Background(), nil); err != nil {
		t.Fatal("retry failed", err)
	}
	if !s.Status(context.Background()).Ready {
		t.Fatal("retry not ready")
	}
	if err := os.Remove(s.Binary()); err != nil {
		t.Fatal(err)
	}
	if s.Status(context.Background()).Ready {
		t.Fatal("missing runtime ready")
	}
}

func TestRuntimeArchiveRejectsUnsafePathsAndLinks(t *testing.T) {
	for _, h := range []tar.Header{
		{Name: "../escape", Typeflag: tar.TypeReg},
		{Name: "/escape", Typeflag: tar.TypeReg},
		{Name: "fixture/../escape", Typeflag: tar.TypeReg},
		{Name: "fixture/sub/libllama.so", Typeflag: tar.TypeReg},
		{Name: "fixture/libllama.so", Typeflag: tar.TypeSymlink, Linkname: "../../escape"},
		{Name: "fixture/libllama.so", Typeflag: tar.TypeLink, Linkname: "libggml.so.0"},
		{Name: "fixture/libllama.so", Typeflag: tar.TypeSymlink, Linkname: "libllama.so"},
	} {
		t.Run(strings.ReplaceAll(h.Name, "/", "-"), func(t *testing.T) {
			dir := t.TempDir()
			file := filepath.Join(dir, "runtime.tar.gz")
			if err := os.WriteFile(file, runtimeArchive(t, h), 0600); err != nil {
				t.Fatal(err)
			}
			if err := extractRuntime(context.Background(), file, filepath.Join(dir, "runtime"), "fixture"); err == nil {
				t.Fatal("accepted unsafe archive", h)
			}
		})
	}
}

// Opt-in: the validation harness prepares a real bundle in a temporary XDG
// tree. Normal tests never download models or touch the user's installation.
func TestPreparedBundleRealInference(t *testing.T) {
	dir := os.Getenv("SENDA_TEST_POSTPROCESS_BUNDLE")
	if dir == "" {
		t.Skip("no temporary real bundle supplied")
	}
	s := NewStore(dir)
	if !s.Status(context.Background()).Ready {
		t.Fatal("real bundle not ready")
	}
	var raw []byte
	var runErr error
	p := Processor{Model: s.ModelPath(), Run: func(ctx context.Context, in io.Reader, args ...string) ([]byte, error) {
		raw, runErr = executeLocal(ctx, in, s.Binary(), args...)
		return raw, runErr
	}}
	before := time.Now()
	got, err := p.Process(context.Background(), "hola como estas")
	if err != nil || runErr != nil || got == "hola como estas" || !Accept("hola como estas", got) {
		t.Fatalf("real inference: result=%q raw=%q error=%v runtime=%v elapsed=%s", got, raw, err, runErr, time.Since(before))
	}
	t.Logf("real inference: %q -> %q in %s", "hola como estas", got, time.Since(before))
}
