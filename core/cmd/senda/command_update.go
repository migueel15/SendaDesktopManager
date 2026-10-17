package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/release"
	"github.com/migueel15/SendaDesktopManager/core/internal/version"
	"github.com/spf13/cobra"
)

const (
	latestReleaseAPI = "https://api.github.com"
	releaseDownload  = "https://github.com/migueel15/SendaDesktopManager/releases/download"
	checksumsAsset   = "checksums.txt"
)

// managedEntries are the entries of the Quickshell tarball that replace the
// matching entries in DataDir during an update.
var managedEntries = []string{"quickshell", "scripts", "version"}

// updateCmd returns the command that updates senda and its Quickshell files
// to the latest GitHub release.
func updateCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "update",
		Short: "update senda and the Quickshell files to the latest release",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runUpdate(cmd)
		},
	}
}

func runUpdate(cmd *cobra.Command) error {
	out := cmd.OutOrStdout()

	if version.Version == "dev" {
		return errors.New("esta compilación es de desarrollo; no se puede actualizar")
	}
	if paths.Setting("SENDA_HOME") != "" {
		return errors.New("SENDA_HOME está definido para desarrollo; la actualización está deshabilitada")
	}

	ctx := cmd.Context()
	tag, err := release.LatestTag(ctx, latestReleaseAPI)
	if err != nil {
		return err
	}

	// The binary only needs replacing when the release differs from this build.
	// Quickshell files are always synced when their version file does not match.
	binaryNeeded := tag != version.Version
	installed := readInstalledVersion()
	if !binaryNeeded {
		if installed == tag {
			fmt.Fprintf(out, "Ya tienes la última versión (%s)\n", tag)
			return nil
		}
		fmt.Fprintf(out, "Ya tienes la última versión (%s); se sincronizan los archivos de Quickshell\n", tag)
	}

	// Download and verify everything before changing anything on disk.
	tmp, err := os.MkdirTemp("", "senda-update-")
	if err != nil {
		return fmt.Errorf("crear directorio temporal: %w", err)
	}
	defer os.RemoveAll(tmp)

	binaryAsset := fmt.Sprintf("senda-%s-linux-amd64", tag)
	tarballAsset := fmt.Sprintf("senda-quickshell-%s.tar.gz", tag)
	checksums := filepath.Join(tmp, checksumsAsset)
	binaryPath := filepath.Join(tmp, binaryAsset)
	tarPath := filepath.Join(tmp, tarballAsset)

	if err := downloadAsset(ctx, tag, checksumsAsset, checksums); err != nil {
		return err
	}
	if binaryNeeded {
		if err := downloadAsset(ctx, tag, binaryAsset, binaryPath); err != nil {
			return err
		}
		if err := release.VerifyChecksum(checksums, binaryAsset, binaryPath); err != nil {
			return err
		}
	}
	if err := downloadAsset(ctx, tag, tarballAsset, tarPath); err != nil {
		return err
	}
	if err := release.VerifyChecksum(checksums, tarballAsset, tarPath); err != nil {
		return err
	}

	// Resolve the binary location before touching the data directory, so a
	// failure here cannot leave Quickshell files updated without the binary.
	exe, err := resolveExecutable()
	if err != nil {
		return err
	}

	dataDir := paths.DataDir()
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return fmt.Errorf("crear %s: %w", dataDir, err)
	}

	// The staging directory lives inside DataDir so that renames stay on one
	// filesystem and are atomic.
	stage, err := os.MkdirTemp(dataDir, ".update-stage-")
	if err != nil {
		return fmt.Errorf("crear directorio de preparación: %w", err)
	}
	defer os.RemoveAll(stage)

	if err := release.ExtractDataTarball(tarPath, stage); err != nil {
		return err
	}
	if err := installManaged(dataDir, stage); err != nil {
		return err
	}

	if binaryNeeded {
		if err := release.ReplaceFileAtomic(binaryPath, exe, 0o755); err != nil {
			return fmt.Errorf("reemplazar el binario: %w", err)
		}
	}

	if !closeShell() {
		return errors.New("no se pudo detener Quickshell; ciérralo y ejecuta 'senda shell run'")
	}
	// Quickshell is always restarted after an update, because its files were
	// overwritten. Start it detached so this process can exit.
	shell := exec.Command(exe, "shell", "run")
	shell.Stdin = nil
	shell.Stdout = nil
	shell.Stderr = nil
	shell.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := shell.Start(); err != nil {
		return fmt.Errorf("reiniciar Quickshell: %w", err)
	}
	fmt.Fprintln(out, "Quickshell reiniciado")

	if binaryNeeded {
		fmt.Fprintf(out, "senda actualizado de %s a %s\n", version.Version, tag)
	} else {
		fmt.Fprintf(out, "Quickshell sincronizado con %s\n", tag)
	}
	return nil
}

// downloadAsset fetches one asset of the given release tag into dst.
func downloadAsset(ctx context.Context, tag string, asset string, dst string) error {
	return release.Download(ctx, releaseDownload+"/"+tag+"/"+asset, dst)
}

// readInstalledVersion returns the release recorded in the version file, or
// an empty string when it is missing.
func readInstalledVersion() string {
	data, err := os.ReadFile(paths.VersionFile())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// resolveExecutable returns the real path of the running binary, following
// symlinks so the file that is replaced is the one actually executed.
func resolveExecutable() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("localizar el binario: %w", err)
	}
	resolved, err := filepath.EvalSymlinks(exe)
	if err != nil {
		return "", fmt.Errorf("resolver el binario %s: %w", exe, err)
	}
	return resolved, nil
}

// installManaged swaps the managed entries from stage into dataDir. Each old
// entry is renamed to "<name>.old" first, and the old copies are removed once
// every entry is in place. A failure restores the previous entries.
func installManaged(dataDir string, stage string) error {
	for _, name := range managedEntries {
		if _, err := os.Lstat(filepath.Join(stage, name)); err != nil {
			return fmt.Errorf("el paquete de Quickshell no contiene %s", name)
		}
	}

	var moved, placed []string
	rollback := func() {
		for _, name := range placed {
			os.RemoveAll(filepath.Join(dataDir, name))
		}
		for _, name := range moved {
			dst := filepath.Join(dataDir, name)
			os.Rename(dst+".old", dst)
		}
	}

	for _, name := range managedEntries {
		dst := filepath.Join(dataDir, name)
		old := dst + ".old"

		if err := os.RemoveAll(old); err != nil {
			rollback()
			return fmt.Errorf("limpiar %s: %w", old, err)
		}
		if _, err := os.Lstat(dst); err == nil {
			if err := os.Rename(dst, old); err != nil {
				rollback()
				return fmt.Errorf("mover %s: %w", dst, err)
			}
			moved = append(moved, name)
		}

		if err := os.Rename(filepath.Join(stage, name), dst); err != nil {
			rollback()
			return fmt.Errorf("instalar %s: %w", dst, err)
		}
		placed = append(placed, name)
	}

	// Best effort: any leftover .old copy is removed at the next update.
	for _, name := range moved {
		os.RemoveAll(filepath.Join(dataDir, name) + ".old")
	}
	return nil
}
