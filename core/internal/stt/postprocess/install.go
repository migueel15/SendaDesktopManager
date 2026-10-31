package postprocess

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// Artifacts are pinned to immutable revisions and verified before use. Never
// resolve 'latest' at install time, or download anything during dictation.
type Artifact struct {
	URL, SHA256 string
	Size        int64
}

type Store struct {
	Dir            string
	Runtime, Model Artifact
	ArchiveRoot    string
	Supported      bool
	Client         *http.Client
	CheckRuntime   func(context.Context, string) error
}

func NewStore(dir string) *Store {
	return &Store{Dir: dir, Supported: runtime.GOOS == "linux" && runtime.GOARCH == "amd64", ArchiveRoot: "llama-b11979",
		Runtime: Artifact{"https://github.com/ggml-org/llama.cpp/releases/download/b11979/llama-b11979-bin-ubuntu-x64.tar.gz", "437879071395165dafd08bbd70f9eb9b0353698b5278d09504a2a97b46e81130", 22692548},
		Model:   Artifact{"https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/d7f544eead698dbd1f15126ef60b45a1e1933222/Qwen3-1.7B-Q4_K_M.gguf", "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897", 1107409472},
		Client:  &http.Client{Timeout: 30 * time.Minute}, CheckRuntime: checkRuntime}
}

func ManagedStore() *Store         { return NewStore(filepath.Join(stt.Dir(), "postprocess")) }
func (s *Store) Binary() string    { return filepath.Join(s.Dir, "runtime", "llama-completion") }
func (s *Store) ModelPath() string { return filepath.Join(s.Dir, "qwen3-1.7b-q4-k-m.gguf") }

type InstallStatus struct {
	Ready     bool   `json:"ready"`
	Supported bool   `json:"supported"`
	Message   string `json:"message"`
	SizeBytes int64  `json:"sizeBytes"`
}

type bundleManifest struct{ RuntimeSHA256, ModelSHA256 string }

func (s *Store) Status(ctx context.Context) InstallStatus {
	status := InstallStatus{Supported: s.Supported, SizeBytes: s.Runtime.Size + s.Model.Size, Message: "Pendiente de preparar"}
	if !s.Supported {
		status.Message = "La corrección automática requiere Linux x86-64"
		return status
	}
	var m bundleManifest
	data, err := os.ReadFile(filepath.Join(s.Dir, "bundle.json"))
	if err != nil || json.Unmarshal(data, &m) != nil || m.RuntimeSHA256 != s.Runtime.SHA256 || m.ModelSHA256 != s.Model.SHA256 {
		return status
	}
	if info, err := os.Stat(s.ModelPath()); err != nil || !info.Mode().IsRegular() || info.Size() != s.Model.Size {
		return status
	}
	if err := verifyGGUF(s.ModelPath()); err != nil {
		return status
	}
	if err := s.CheckRuntime(ctx, s.Binary()); err != nil {
		status.Message = "El motor local no puede ejecutarse; vuelve a preparar la corrección"
		return status
	}
	status.Ready, status.Message = true, "Preparada"
	return status
}

func checkRuntime(ctx context.Context, binary string) error {
	info, err := os.Stat(binary)
	if err != nil || !info.Mode().IsRegular() || info.Mode().Perm()&0111 == 0 {
		return fmt.Errorf("motor de corrección no disponible")
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	_, err = executeLocal(ctx, nil, binary, "--version")
	if err != nil {
		return fmt.Errorf("el motor de corrección no puede ejecutarse en este equipo: %w", err)
	}
	return nil
}

// Install stages and verifies both artifacts before replacing an installation.
// Cancellation/failure leaves the previous bundle untouched and removes staging.
func (s *Store) Install(ctx context.Context, progress func(string, int64, int64)) error {
	if !s.Supported {
		return fmt.Errorf("la preparación automática requiere Linux x86-64")
	}
	if s.Status(ctx).Ready {
		return nil
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	parent := filepath.Dir(s.Dir)
	if err := os.MkdirAll(parent, 0700); err != nil {
		return err
	}
	stage, err := os.MkdirTemp(parent, ".postprocess-install-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(stage)
	total := s.Runtime.Size + s.Model.Size
	report := func(phase string, offset int64) func(int64) {
		return func(done int64) {
			if progress != nil {
				progress(phase, offset+done, total)
			}
		}
	}
	archive := filepath.Join(stage, "runtime.tar.gz")
	if err := s.download(ctx, s.Runtime, archive, report("Descargando motor", 0)); err != nil {
		return fmt.Errorf("descargar motor: %w", err)
	}
	runtimeDir := filepath.Join(stage, "runtime")
	if err := extractRuntime(ctx, archive, runtimeDir, s.ArchiveRoot); err != nil {
		return err
	}
	if err := os.Remove(archive); err != nil {
		return err
	}
	if err := s.CheckRuntime(ctx, filepath.Join(runtimeDir, "llama-completion")); err != nil {
		return err
	}
	model := filepath.Join(stage, filepath.Base(s.ModelPath()))
	if err := s.download(ctx, s.Model, model, report("Descargando modelo", s.Runtime.Size)); err != nil {
		return fmt.Errorf("descargar modelo: %w", err)
	}
	if err := verifyGGUF(model); err != nil {
		return err
	}
	data, err := json.Marshal(bundleManifest{s.Runtime.SHA256, s.Model.SHA256})
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(stage, "bundle.json"), data, 0600); err != nil {
		return err
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	// Same staging/rename pattern as the STT runtime, with rollback on failure.
	backup := stage + "-previous"
	if _, err := os.Lstat(s.Dir); err == nil {
		if err := os.Rename(s.Dir, backup); err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	if err := os.Rename(stage, s.Dir); err != nil {
		if _, e := os.Lstat(backup); e == nil {
			if e := os.Rename(backup, s.Dir); e != nil {
				return fmt.Errorf("activar corrección: %v; restaurar: %w", err, e)
			}
		}
		return err
	}
	return os.RemoveAll(backup)
}

func verifyGGUF(name string) error {
	f, err := os.Open(name)
	if err != nil {
		return err
	}
	defer f.Close()
	var magic [4]byte
	if _, err := io.ReadFull(f, magic[:]); err != nil || string(magic[:]) != "GGUF" {
		return fmt.Errorf("modelo de corrección GGUF inválido")
	}
	return nil
}

func (s *Store) download(ctx context.Context, a Artifact, dest string, progress func(int64)) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.URL, nil)
	if err != nil {
		return err
	}
	resp, err := s.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %s", resp.Status)
	}
	f, err := os.OpenFile(dest, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	hash := sha256.New()
	var done int64
	last := time.Time{}
	buffer := make([]byte, 128*1024)
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		n, readErr := resp.Body.Read(buffer)
		if n > 0 {
			done += int64(n)
			if done > a.Size {
				return fmt.Errorf("descarga mayor que el tamaño esperado")
			}
			if _, err := io.MultiWriter(f, hash).Write(buffer[:n]); err != nil {
				return err
			}
			if time.Since(last) > 100*time.Millisecond || done == a.Size {
				if progress != nil {
					progress(done)
				}
				last = time.Now()
			}
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			return readErr
		}
	}
	if done != a.Size || hex.EncodeToString(hash.Sum(nil)) != a.SHA256 {
		return fmt.Errorf("el tamaño o SHA-256 de la descarga no coincide")
	}
	return f.Close()
}

func runtimeFile(name string) bool {
	return name == "llama-completion" || name == "LICENSE" ||
		(strings.HasPrefix(name, "libggml") && name != "libggml-rpc.so" || strings.HasPrefix(name, "libllama")) && strings.Contains(name, ".so")
}

// Extract only the completion binary and libraries. Symlinks must stay within
// the flat runtime directory and resolve to a regular extracted library.
func extractRuntime(ctx context.Context, archive, dest, root string) error {
	f, err := os.Open(archive)
	if err != nil {
		return err
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		return err
	}
	defer gz.Close()
	if err := os.Mkdir(dest, 0700); err != nil {
		return err
	}
	tr := tar.NewReader(gz)
	links := map[string]string{}
	var size int64
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		if path.Clean(h.Name) != strings.TrimSuffix(h.Name, "/") || strings.Contains(h.Name, "\\") || h.Name != root && !strings.HasPrefix(h.Name, root+"/") {
			return fmt.Errorf("ruta insegura en el motor: %q", h.Name)
		}
		if h.Typeflag == tar.TypeDir && strings.TrimSuffix(h.Name, "/") == root {
			continue
		}
		name := strings.TrimPrefix(h.Name, root+"/")
		if path.Base(name) != name {
			return fmt.Errorf("ruta inesperada del motor: %q", h.Name)
		}
		if !runtimeFile(name) {
			continue
		}
		targetName := name
		if name == "LICENSE" {
			targetName = "license"
		}
		target := filepath.Join(dest, targetName)
		switch h.Typeflag {
		case tar.TypeReg, tar.TypeRegA:
			size += h.Size
			if h.Size < 0 || size > 256*1024*1024 {
				return fmt.Errorf("motor descomprimido demasiado grande")
			}
			out, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0700)
			if err != nil {
				return err
			}
			_, copyErr := io.Copy(out, tr)
			closeErr := out.Close()
			if copyErr != nil {
				return copyErr
			}
			if closeErr != nil {
				return closeErr
			}
		case tar.TypeSymlink:
			if name == "llama-completion" || path.Base(h.Linkname) != h.Linkname || !runtimeFile(h.Linkname) {
				return fmt.Errorf("enlace inseguro del motor")
			}
			links[name] = h.Linkname
		default:
			return fmt.Errorf("tipo de archivo del motor no permitido")
		}
	}
	for name, target := range links {
		if err := os.Symlink(target, filepath.Join(dest, name)); err != nil {
			return err
		}
	}
	for name := range links {
		resolved, err := filepath.EvalSymlinks(filepath.Join(dest, name))
		if err != nil || filepath.Dir(resolved) != dest {
			return fmt.Errorf("enlace del motor no válido")
		}
		info, err := os.Stat(resolved)
		if err != nil || !info.Mode().IsRegular() {
			return fmt.Errorf("biblioteca del motor no válida")
		}
	}
	return nil
}
