package release

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// ExtractDataTarball unpacks the Quickshell tarball into dstDir, which the
// caller must create. Only the managed entries are accepted: the file
// "version", and the directories "quickshell" and "scripts" with their
// contents. Symlinks, hard links, absolute paths and ".." segments are
// rejected, and the whole archive is refused on the first invalid entry.
func ExtractDataTarball(tarPath string, dstDir string) error {
	f, err := os.Open(tarPath)
	if err != nil {
		return fmt.Errorf("abrir %s: %w", tarPath, err)
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return fmt.Errorf("leer gzip de %s: %w", tarPath, err)
	}
	defer gz.Close()

	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return fmt.Errorf("leer tar de %s: %w", tarPath, err)
		}

		rel, err := checkEntry(hdr)
		if err != nil {
			return err
		}

		target := filepath.Join(dstDir, filepath.FromSlash(rel))
		if hdr.Typeflag == tar.TypeDir {
			if err := os.MkdirAll(target, 0o755); err != nil {
				return fmt.Errorf("crear directorio %s: %w", rel, err)
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return fmt.Errorf("crear directorio para %s: %w", rel, err)
		}
		if err := writeRegular(target, tr); err != nil {
			return fmt.Errorf("extraer %s: %w", rel, err)
		}
	}
}

// checkEntry validates one tar header and returns its cleaned relative name.
func checkEntry(hdr *tar.Header) (string, error) {
	name := hdr.Name
	if name == "" || strings.HasPrefix(name, "/") || filepath.IsAbs(name) {
		return "", fmt.Errorf("entrada con ruta absoluta o vacía rechazada: %q", name)
	}

	rel := strings.TrimSuffix(name, "/")
	segments := strings.Split(rel, "/")
	for _, s := range segments {
		if s == "" || s == "." || s == ".." {
			return "", fmt.Errorf("entrada con ruta no permitida: %q", name)
		}
	}

	if hdr.Typeflag != tar.TypeDir && hdr.Typeflag != tar.TypeReg {
		return "", fmt.Errorf("tipo de entrada no permitido en %q", name)
	}

	top := segments[0]
	if len(segments) == 1 {
		switch {
		case top == "version" && hdr.Typeflag == tar.TypeReg:
			return rel, nil
		case (top == "quickshell" || top == "scripts") && hdr.Typeflag == tar.TypeDir:
			return rel, nil
		}
		return "", fmt.Errorf("entrada no permitida: %q", name)
	}

	if top != "quickshell" && top != "scripts" {
		return "", fmt.Errorf("entrada fuera de quickshell/ y scripts/ rechazada: %q", name)
	}
	return rel, nil
}

func writeRegular(target string, r io.Reader) error {
	out, err := os.OpenFile(target, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, r); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}
