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
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/discordbridge"
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

// updateCmd returns the command that updates senda and its Quickshell files
// to the latest GitHub release. With --check it only reports whether a newer
// release exists.
func updateCmd() *cobra.Command {
	var check bool
	cmd := &cobra.Command{
		Use:   "update",
		Short: "update senda and the Quickshell files to the latest release",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if check {
				return runCheck(cmd)
			}
			return runUpdate(cmd)
		},
	}
	cmd.Flags().BoolVar(&check, "check", false, "print as JSON whether a newer release exists, without changing anything")
	return cmd
}

// availableUpdate reports whether latest differs from the installed build.
// Development builds never report an update, because they cannot be updated.
func availableUpdate(current string, latest string) bool {
	return current != "dev" && latest != "" && latest != current
}

func runCheck(cmd *cobra.Command) error {
	tag, err := release.LatestTag(cmd.Context(), latestReleaseAPI)
	if err != nil {
		return err
	}
	return writeJSON(cmd, map[string]any{
		"current":   version.Version,
		"latest":    tag,
		"available": availableUpdate(version.Version, tag),
	})
}

func runUpdate(cmd *cobra.Command) error {
	out := cmd.OutOrStdout()

	if version.Version == "dev" {
		return errors.New("esta compilación es de desarrollo; no se puede actualizar")
	}
	if os.Getenv("SENDA_HOME") != "" {
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

	if err := release.InstallData(tarPath, paths.DataDir()); err != nil {
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
	// The Discord bridge keeps running the script it was started from, so stop
	// it too; Quickshell starts the updated one when it reconnects.
	if err := discordbridge.Stop(discordbridge.SocketPath(), 3*time.Second); err != nil {
		fmt.Fprintln(cmd.ErrOrStderr(), "aviso:", err)
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
