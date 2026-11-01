package models

import (
	"archive/tar"
	"compress/bzip2"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func (s *Store) entry(id string) (Entry, bool) {
	for _, e := range s.Catalog {
		if e.ID == id {
			return e, true
		}
	}
	return Entry{}, false
}

func (s *Store) ModelDir(id string) string {
	if _, ok := s.entry(id); !ok {
		return ""
	}
	return filepath.Join(s.Dir, id)
}

func (s *Store) Installed(id string) bool {
	e, ok := s.entry(id)
	if !ok {
		return false
	}
	dir := s.ModelDir(id)
	m, err := stt.ReadManifest(dir)
	if err != nil || m.ID != id || m.Kind != e.ManifestKind() || m.LanguageOption != e.LanguageOption ||
		m.Encoder != e.Files.Encoder || m.Decoder != e.Files.Decoder || m.Joiner != e.Files.Joiner || m.Tokens != e.Files.Tokens {
		return false
	}
	return verifyFiles(dir, e.Files) == nil
}

func (s *Store) List(active string) ([]Status, error) {
	out := make([]Status, 0, len(s.Catalog))
	for _, e := range s.Catalog {
		e.Languages = append([]string(nil), e.Languages...)
		out = append(out, Status{Entry: e, Installed: s.Installed(e.ID), Active: e.ID == active})
	}
	return out, nil
}

func (s *Store) Remove(id string) error {
	if _, ok := s.entry(id); !ok {
		return ErrUnknownModel
	}
	return os.RemoveAll(s.ModelDir(id))
}

func (s *Store) Install(ctx context.Context, id string, progress func(int64, int64)) error {
	e, ok := s.entry(id)
	if !ok {
		return ErrUnknownModel
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if s.Installed(id) {
		return nil
	}
	if err := os.MkdirAll(s.Dir, 0o700); err != nil {
		return err
	}
	archive, err := os.CreateTemp(s.Dir, ".model-download-*.tar.bz2")
	if err != nil {
		return err
	}
	defer os.Remove(archive.Name())
	defer archive.Close()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, e.URL, nil)
	if err != nil {
		return err
	}
	client := s.Client
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("descarga de %s: HTTP %s", id, resp.Status)
	}
	total := e.SizeBytes
	if total <= 0 {
		total = resp.ContentLength
	}
	hash := sha256.New()
	buf := make([]byte, 128*1024)
	var done int64
	for {
		n, readErr := resp.Body.Read(buf)
		if n > 0 {
			if _, err := archive.Write(buf[:n]); err != nil {
				return err
			}
			if _, err := hash.Write(buf[:n]); err != nil {
				return err
			}
			done += int64(n)
			if progress != nil {
				progress(done, total)
			}
		}
		if err := ctx.Err(); err != nil {
			return err
		}
		if readErr == io.EOF {
			break
		}
		if readErr != nil {
			return readErr
		}
	}
	if e.SizeBytes > 0 && done != e.SizeBytes {
		return fmt.Errorf("tamaño de %s: recibido %d, esperado %d", id, done, e.SizeBytes)
	}
	if !strings.EqualFold(hex.EncodeToString(hash.Sum(nil)), e.SHA256) {
		return ErrChecksum
	}
	if _, err := archive.Seek(0, io.SeekStart); err != nil {
		return err
	}
	staging, err := os.MkdirTemp(s.Dir, ".model-extract-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(staging)
	if err := extract(ctx, archive, staging, e.Archive); err != nil {
		return err
	}
	if err := verifyFiles(staging, e.Files); err != nil {
		return err
	}
	m := stt.Manifest{ID: id, Kind: e.ManifestKind(), Encoder: e.Files.Encoder, Decoder: e.Files.Decoder, Joiner: e.Files.Joiner, Tokens: e.Files.Tokens, LanguageOption: e.LanguageOption}
	if err := stt.WriteManifest(staging, m); err != nil {
		return err
	}
	if _, err := stt.ReadManifest(staging); err != nil {
		return err
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	dest := s.ModelDir(id)
	if _, err := os.Lstat(dest); err == nil {
		if s.Installed(id) {
			return nil
		}
		if err := os.RemoveAll(dest); err != nil {
			return err
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return os.Rename(staging, dest)
}

func verifyFiles(dir string, files ModelFiles) error {
	for _, name := range []string{files.Encoder, files.Decoder, files.Joiner, files.Tokens} {
		if name == "" || path.IsAbs(name) || strings.Contains(name, "\\") || path.Clean(name) != name || name == ".." || strings.HasPrefix(name, "../") {
			return fmt.Errorf("ruta de modelo inválida: %q", name)
		}
		info, err := os.Lstat(filepath.Join(dir, filepath.FromSlash(name)))
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("archivo de modelo no regular: %s", name)
		}
	}
	return nil
}

func extract(ctx context.Context, source io.Reader, dest, archiveRoot string) error {
	tr := tar.NewReader(bzip2.NewReader(source))
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		header, err := tr.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		name := header.Name
		if path.IsAbs(name) || strings.Contains(name, "\\") || path.Clean(name) != strings.TrimSuffix(name, "/") || strings.HasPrefix(name, "../") || name == ".." {
			return fmt.Errorf("ruta insegura en el archivo: %q", name)
		}
		relative := strings.TrimPrefix(name, archiveRoot+"/")
		if name != archiveRoot && !strings.HasPrefix(name, archiveRoot+"/") {
			return fmt.Errorf("raíz inesperada en el archivo: %q", name)
		}
		if relative == archiveRoot || relative == "" {
			if header.Typeflag != tar.TypeDir {
				return fmt.Errorf("raíz inválida: %q", name)
			}
			continue
		}
		target := filepath.Join(dest, filepath.FromSlash(relative))
		switch header.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0o700); err != nil {
				return err
			}
		case tar.TypeReg, tar.TypeRegA:
			if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
				return err
			}
			file, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
			if err != nil {
				return err
			}
			_, copyErr := io.Copy(file, &contextReader{ctx: ctx, reader: tr})
			closeErr := file.Close()
			if copyErr != nil {
				return copyErr
			}
			if closeErr != nil {
				return closeErr
			}
		default:
			return fmt.Errorf("tipo de archivo no permitido: %q", name)
		}
	}
}

type contextReader struct {
	ctx    context.Context
	reader io.Reader
}

func (r *contextReader) Read(p []byte) (int, error) {
	if err := r.ctx.Err(); err != nil {
		return 0, err
	}
	return r.reader.Read(p)
}
