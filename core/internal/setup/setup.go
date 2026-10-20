package setup

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/release"
)

// Pacman is the package manager boundary used by the dependency step.
type Pacman interface {
	// Known reports whether pacman has pkg in its sync databases.
	Known(pkg string) (bool, error)
	// Installed reports whether pkg is installed on the system.
	Installed(pkg string) bool
	// Install installs pkgs with sudo pacman -S --needed on the terminal.
	Install(pkgs []string) error
}

// Options holds the environment and external commands that Run uses. Tests
// replace them with fakes; the command wires the real implementations.
type Options struct {
	In              io.Reader
	Out             io.Writer
	Getenv          func(string) string
	Euid            int
	OSReleasePath   string
	LookPath        func(file string) (string, error)
	Pacman          Pacman
	Executable      func() (string, error)
	StartShell      func(exe string) error
	ReleaseAPI      string
	ReleaseDownload string
}

// checksumsAsset is the checksums file published with every release.
const checksumsAsset = "checksums.txt"

// Run performs the setup steps in order and stops at the first failed
// prerequisite. It never edits Hyprland files: autostart is handled by the
// senda.service user unit.
func Run(ctx context.Context, opts Options) error {
	if opts.In == nil {
		opts.In = strings.NewReader("")
	}
	reader := bufio.NewReader(opts.In)

	if err := CheckNotRoot(opts.Euid); err != nil {
		return err
	}

	if err := checkOSRelease(opts.OSReleasePath); err != nil {
		return err
	}
	if err := CheckCompositor(opts.Getenv); err != nil {
		return err
	}
	if err := checkDependencies(opts, reader); err != nil {
		return err
	}
	if err := ensureConfig(paths.ConfigDir(), paths.ConfigFile(), opts.Out); err != nil {
		return err
	}
	if err := installQuickshell(ctx, opts); err != nil {
		return err
	}

	exe, err := resolveExecutable(opts.Executable)
	if err != nil {
		return err
	}
	if err := opts.StartShell(exe); err != nil {
		return fmt.Errorf("instalar el servicio de Senda: %w", err)
	}
	fmt.Fprintln(opts.Out, "Servicio senda.service instalado y activo; Senda arrancará en cada inicio de sesión")
	fmt.Fprintln(opts.Out, "Si tu configuración de Hyprland lanza 'senda shell run', quita esa línea")
	return nil
}

func checkOSRelease(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("leer /etc/os-release: %w", err)
	}
	defer f.Close()
	return CheckDistribution(f)
}

// checkDependencies reports missing commands and, after an explicit "s",
// installs the ones pacman knows. Unknown packages are left for the user.
func checkDependencies(opts Options, in *bufio.Reader) error {
	missing := MissingRequirements(opts.LookPath, opts.Pacman.Installed)
	if len(missing) == 0 {
		fmt.Fprintln(opts.Out, "Dependencias presentes")
		return nil
	}

	fmt.Fprintln(opts.Out, "Faltan dependencias:")
	pkgs := make([]string, 0, len(missing))
	for _, req := range missing {
		if req.Command == "" {
			fmt.Fprintf(opts.Out, "  paquete %s\n", req.Package)
		} else {
			fmt.Fprintf(opts.Out, "  %s (paquete %s)\n", req.Command, req.Package)
		}
		pkgs = append(pkgs, req.Package)
	}

	if !confirmInstall(in, opts.Out) {
		for _, pkg := range pkgs {
			fmt.Fprintf(opts.Out, "instala manualmente: %s\n", pkg)
		}
		return nil
	}

	var official []string
	for _, pkg := range pkgs {
		known, err := opts.Pacman.Known(pkg)
		if err != nil {
			return err
		}
		if known {
			official = append(official, pkg)
			continue
		}
		fmt.Fprintf(opts.Out, "instala manualmente desde AUR: %s\n", pkg)
	}

	if len(official) == 0 {
		return nil
	}
	if err := opts.Pacman.Install(official); err != nil {
		return fmt.Errorf("instalar paquetes con pacman: %w", err)
	}
	return nil
}

// confirmInstall reads one line and accepts only "s", case-insensitively.
func confirmInstall(in *bufio.Reader, out io.Writer) bool {
	fmt.Fprint(out, "¿Instalar con pacman? [s/N] ")
	line, _ := in.ReadString('\n')
	return strings.EqualFold(strings.TrimSpace(line), "s")
}

// installQuickshell downloads the latest release's Quickshell tarball, verifies
// it and installs it into DataDir. It is skipped when that release is already
// installed.
func installQuickshell(ctx context.Context, opts Options) error {
	if opts.Getenv("SENDA_HOME") != "" {
		return errors.New("SENDA_HOME está definido; setup solo instala releases")
	}

	tag, err := release.LatestTag(ctx, opts.ReleaseAPI)
	if err != nil {
		return err
	}
	if installedVersion(paths.VersionFile()) == tag && dirExists(paths.QuickshellDir()) {
		fmt.Fprintf(opts.Out, "Quickshell ya está instalado (%s)\n", tag)
		return nil
	}

	tmp, err := os.MkdirTemp("", "senda-setup-")
	if err != nil {
		return fmt.Errorf("crear directorio temporal: %w", err)
	}
	defer os.RemoveAll(tmp)

	tarballAsset := fmt.Sprintf("senda-quickshell-%s.tar.gz", tag)
	checksums := filepath.Join(tmp, checksumsAsset)
	tarPath := filepath.Join(tmp, tarballAsset)

	for _, dl := range []struct{ asset, dst string }{{checksumsAsset, checksums}, {tarballAsset, tarPath}} {
		url := opts.ReleaseDownload + "/" + tag + "/" + dl.asset
		if err := release.Download(ctx, url, dl.dst); err != nil {
			return err
		}
	}
	if err := release.VerifyChecksum(checksums, tarballAsset, tarPath); err != nil {
		return err
	}
	if err := release.InstallData(tarPath, paths.DataDir()); err != nil {
		return err
	}
	fmt.Fprintf(opts.Out, "Quickshell instalado (%s)\n", tag)
	return nil
}

// installedVersion returns the release recorded in the version file, or an
// empty string when it is missing.
func installedVersion(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

// resolveExecutable returns the real path of the running binary, following
// symlinks so the unit runs the file that is actually installed.
func resolveExecutable(executable func() (string, error)) (string, error) {
	exe, err := executable()
	if err != nil {
		return "", fmt.Errorf("localizar el binario: %w", err)
	}
	resolved, err := filepath.EvalSymlinks(exe)
	if err != nil {
		return "", fmt.Errorf("resolver el binario %s: %w", exe, err)
	}
	return resolved, nil
}
