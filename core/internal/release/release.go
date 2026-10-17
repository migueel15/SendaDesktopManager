// Package release downloads and verifies Senda release assets from GitHub and
// installs the Quickshell data they contain.
package release

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const (
	repoPath        = "/repos/migueel15/SendaDesktopManager/releases/latest"
	apiTimeout      = 30 * time.Second
	downloadTimeout = 5 * time.Minute
)

// tagPattern accepts only release tags of the form vX.Y.Z.
var tagPattern = regexp.MustCompile(`^v[0-9]+\.[0-9]+\.[0-9]+$`)

// LatestTag asks the releases API under baseURL for the latest release and
// returns its validated tag name. baseURL is https://api.github.com in
// production; tests may use a plain http://127.0.0.1 server.
func LatestTag(ctx context.Context, baseURL string) (string, error) {
	if err := checkURL(baseURL); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(baseURL, "/")+repoPath, nil)
	if err != nil {
		return "", fmt.Errorf("crear la petición de la última versión: %w", err)
	}
	req.Header.Set("Accept", "application/vnd.github+json")

	client := &http.Client{Timeout: apiTimeout}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("consultar la última versión: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("consultar la última versión: estado HTTP %d", resp.StatusCode)
	}

	var latest struct {
		TagName string `json:"tag_name"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&latest); err != nil {
		return "", fmt.Errorf("leer la respuesta de la última versión: %w", err)
	}

	if !tagPattern.MatchString(latest.TagName) {
		return "", fmt.Errorf("etiqueta de versión no válida: %q", latest.TagName)
	}
	return latest.TagName, nil
}

// Download fetches url and writes the response body to dst.
func Download(ctx context.Context, url string, dst string) error {
	if err := checkURL(url); err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("crear la descarga: %w", err)
	}

	client := &http.Client{Timeout: downloadTimeout}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("descargar %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("descargar %s: estado HTTP %d", url, resp.StatusCode)
	}

	out, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("crear %s: %w", dst, err)
	}
	if _, err := io.Copy(out, resp.Body); err != nil {
		out.Close()
		return fmt.Errorf("escribir %s: %w", dst, err)
	}
	if err := out.Close(); err != nil {
		return fmt.Errorf("cerrar %s: %w", dst, err)
	}
	return nil
}

// VerifyChecksum looks up assetName in a sha256sum-format checksums file and
// compares it with the SHA-256 digest of assetPath.
func VerifyChecksum(checksumsPath string, assetName string, assetPath string) error {
	expected, err := lookupChecksum(checksumsPath, assetName)
	if err != nil {
		return err
	}

	actual, err := sha256File(assetPath)
	if err != nil {
		return err
	}

	if !strings.EqualFold(expected, actual) {
		return fmt.Errorf("la suma SHA-256 de %s no coincide: esperada %s, obtenida %s", assetName, expected, actual)
	}
	return nil
}

// ReplaceFileAtomic copies src into a temporary file next to dst, sets its
// mode and renames it over dst, so readers never see a partial file.
func ReplaceFileAtomic(src string, dst string, mode os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("abrir %s: %w", src, err)
	}
	defer in.Close()

	tmp, err := os.CreateTemp(filepath.Dir(dst), "."+filepath.Base(dst)+".tmp-*")
	if err != nil {
		return fmt.Errorf("crear archivo temporal para %s: %w", dst, err)
	}
	tmpPath := tmp.Name()

	if _, err := io.Copy(tmp, in); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return fmt.Errorf("copiar %s: %w", src, err)
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return fmt.Errorf("sincronizar %s: %w", tmpPath, err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("cerrar %s: %w", tmpPath, err)
	}
	if err := os.Chmod(tmpPath, mode); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("cambiar permisos de %s: %w", tmpPath, err)
	}
	if err := os.Rename(tmpPath, dst); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("reemplazar %s: %w", dst, err)
	}
	return nil
}

// checkURL accepts https URLs, plus plain http to the loopback address so
// tests can use httptest servers. Everything else is rejected.
func checkURL(raw string) error {
	u, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("URL no válida: %w", err)
	}
	if u.Scheme == "https" && u.Host != "" {
		return nil
	}
	if u.Scheme == "http" && u.Hostname() == "127.0.0.1" {
		return nil
	}
	return fmt.Errorf("URL no permitida (se requiere https): %s", raw)
}

// lookupChecksum returns the digest listed for assetName. A leading '*' before
// the name, used by sha256sum for binary mode, is ignored.
func lookupChecksum(checksumsPath string, assetName string) (string, error) {
	f, err := os.Open(checksumsPath)
	if err != nil {
		return "", fmt.Errorf("abrir checksums: %w", err)
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		hash, name, ok := strings.Cut(strings.TrimSpace(scanner.Text()), " ")
		if !ok {
			continue
		}
		name = strings.TrimPrefix(strings.TrimSpace(name), "*")
		if name == assetName {
			return hash, nil
		}
	}
	if err := scanner.Err(); err != nil {
		return "", fmt.Errorf("leer checksums: %w", err)
	}
	return "", fmt.Errorf("%s no aparece en checksums.txt", assetName)
}

func sha256File(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("abrir %s: %w", path, err)
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", fmt.Errorf("calcular SHA-256 de %s: %w", path, err)
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
