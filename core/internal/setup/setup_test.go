package setup

import (
	"bufio"
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"
)

// fakePacman records the calls made by the dependency step.
type fakePacman struct {
	known     map[string]bool
	present   map[string]bool
	installed [][]string
}

func (f *fakePacman) Installed(pkg string) bool {
	return f.present[pkg]
}

func (f *fakePacman) Known(pkg string) (bool, error) {
	return f.known[pkg], nil
}

func (f *fakePacman) Install(pkgs []string) error {
	f.installed = append(f.installed, pkgs)
	return nil
}

// commandsExcept returns the commands in Requirements other than the named ones.
func commandsExcept(skip ...string) []string {
	var found []string
	for _, req := range Requirements {
		if req.Command != "" && !slices.Contains(skip, req.Command) {
			found = append(found, req.Command)
		}
	}
	return found
}

// packageOnly returns the packages in Requirements that have no command.
func packageOnly() map[string]bool {
	set := map[string]bool{}
	for _, req := range Requirements {
		if req.Command == "" {
			set[req.Package] = true
		}
	}
	return set
}

// lookPathFound returns a LookPath fake where only the named commands exist.
func lookPathFound(found ...string) func(string) (string, error) {
	set := map[string]bool{}
	for _, f := range found {
		set[f] = true
	}
	return func(file string) (string, error) {
		if set[file] {
			return "/usr/bin/" + file, nil
		}
		return "", errors.New("not found")
	}
}

func envFunc(env map[string]string) func(string) string {
	return func(key string) string { return env[key] }
}

func TestCheckDistribution(t *testing.T) {
	tests := []struct {
		name    string
		content string
		wantErr bool
	}{
		{"arch", "NAME=\"Arch Linux\"\nID=arch\n", false},
		{"arch quoted with comment", "# comment\nID=\"arch\"\n", false},
		{"fedora", "ID=fedora\nID_LIKE=arch\n", true},
		{"id_like only", "ID_LIKE=arch\n", true},
		{"empty", "", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := CheckDistribution(strings.NewReader(tt.content))
			if (err != nil) != tt.wantErr {
				t.Fatalf("CheckDistribution() error = %v, wantErr %v", err, tt.wantErr)
			}
			if err != nil && err.Error() != "solo se soporta Arch Linux en esta versión" {
				t.Fatalf("CheckDistribution() message = %q", err)
			}
		})
	}
}

func TestCheckCompositor(t *testing.T) {
	tests := []struct {
		name    string
		env     map[string]string
		wantErr bool
	}{
		{"xdg hyprland", map[string]string{"XDG_CURRENT_DESKTOP": "Hyprland"}, false},
		{"xdg lowercase", map[string]string{"XDG_CURRENT_DESKTOP": "hyprland"}, false},
		{"instance signature", map[string]string{"HYPRLAND_INSTANCE_SIGNATURE": "abc"}, false},
		{"empty environment", map[string]string{}, true},
		{"other desktop", map[string]string{"XDG_CURRENT_DESKTOP": "GNOME"}, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := CheckCompositor(envFunc(tt.env))
			if (err != nil) != tt.wantErr {
				t.Fatalf("CheckCompositor() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestCheckNotRoot(t *testing.T) {
	if err := CheckNotRoot(0); err == nil {
		t.Error("CheckNotRoot(0) accepted root")
	}
	if err := CheckNotRoot(1000); err != nil {
		t.Errorf("CheckNotRoot(1000) = %v", err)
	}
}

func TestMissingRequirementsChecksCommandsAndPackages(t *testing.T) {
	present := packageOnly()
	delete(present, "inter-font")

	missing := MissingRequirements(lookPathFound(commandsExcept("qs", "ddcutil")...),
		func(pkg string) bool { return present[pkg] })
	want := []Requirement{
		{Command: "qs", Package: "quickshell"},
		{Command: "ddcutil", Package: "ddcutil"},
		{Package: "inter-font"},
	}
	if !reflect.DeepEqual(missing, want) {
		t.Fatalf("MissingRequirements() = %v, want %v", missing, want)
	}
}

func TestRequirementsHavePackages(t *testing.T) {
	seen := map[Requirement]bool{}
	for _, req := range Requirements {
		if req.Package == "" {
			t.Errorf("requirement %q has no package", req.Command)
		}
		if seen[req] {
			t.Errorf("requirement %v is listed twice", req)
		}
		seen[req] = true
	}
}

func TestEnsureConfigCreatesTemplateWithOwnerMode(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "senda")
	file := filepath.Join(dir, "config")

	if err := ensureConfig(dir, file, &strings.Builder{}); err != nil {
		t.Fatalf("ensureConfig() error = %v", err)
	}

	info, err := os.Stat(file)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Errorf("config mode = %o, want 600", info.Mode().Perm())
	}
	dirInfo, err := os.Stat(dir)
	if err != nil {
		t.Fatal(err)
	}
	if dirInfo.Mode().Perm() != 0o700 {
		t.Errorf("config dir mode = %o, want 700", dirInfo.Mode().Perm())
	}
	data, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "DORLAB_API_KEY=") {
		t.Errorf("template has a secret key:\n%s", data)
	}
}

func TestEnsureConfigNeverOverwrites(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "config")
	const existing = "DORLAB_API_KEY=secret-value\n"
	if err := os.WriteFile(file, []byte(existing), 0o600); err != nil {
		t.Fatal(err)
	}

	out := &strings.Builder{}
	if err := ensureConfig(dir, file, out); err != nil {
		t.Fatalf("ensureConfig() error = %v", err)
	}
	data, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != existing {
		t.Fatalf("existing config was overwritten: %q", data)
	}
	if strings.Contains(out.String(), "secret-value") {
		t.Fatal("ensureConfig() printed a secret value")
	}
}

func TestCheckDependenciesDeclinedInstallsNothing(t *testing.T) {
	pacman := &fakePacman{known: map[string]bool{"quickshell": true}}
	out := &strings.Builder{}
	opts := Options{
		Out:      out,
		LookPath: lookPathFound(commandsExcept("qs")...),
		Pacman:   pacman,
	}

	if err := checkDependencies(opts, bufio.NewReader(strings.NewReader("\n"))); err != nil {
		t.Fatalf("checkDependencies() error = %v", err)
	}
	if len(pacman.installed) != 0 {
		t.Fatalf("pacman installed %v without consent", pacman.installed)
	}
	if !strings.Contains(out.String(), "instala manualmente: quickshell") {
		t.Errorf("manual list missing from output:\n%s", out)
	}
}

func TestCheckDependenciesInstallsKnownAndReportsAUR(t *testing.T) {
	pacman := &fakePacman{
		known:   map[string]bool{"quickshell": true, "networkmanager": true, "inter-font": true},
		present: packageOnly(),
	}
	delete(pacman.present, "inter-font")
	out := &strings.Builder{}
	opts := Options{
		Out:      out,
		LookPath: lookPathFound(commandsExcept("qs", "nmcli", "blueberry")...),
		Pacman:   pacman,
	}

	if err := checkDependencies(opts, bufio.NewReader(strings.NewReader("S\n"))); err != nil {
		t.Fatalf("checkDependencies() error = %v", err)
	}
	want := [][]string{{"quickshell", "networkmanager", "inter-font"}}
	if !reflect.DeepEqual(pacman.installed, want) {
		t.Fatalf("installed = %v, want %v", pacman.installed, want)
	}
}

func TestRunStopsAtFirstFailedPrerequisite(t *testing.T) {
	osRelease := filepath.Join(t.TempDir(), "os-release")
	if err := os.WriteFile(osRelease, []byte("ID=ubuntu\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	lookedUp := false
	opts := Options{
		Out:           &strings.Builder{},
		Getenv:        envFunc(map[string]string{"XDG_CURRENT_DESKTOP": "Hyprland"}),
		Euid:          1000,
		OSReleasePath: osRelease,
		LookPath: func(string) (string, error) {
			lookedUp = true
			return "", errors.New("not found")
		},
	}

	err := Run(context.Background(), opts)
	if err == nil || err.Error() != "solo se soporta Arch Linux en esta versión" {
		t.Fatalf("Run() error = %v", err)
	}
	if lookedUp {
		t.Fatal("Run() checked dependencies after a failed distribution check")
	}
}

func TestRunRefusesSendaHomeBeforeDownloading(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))

	osRelease := filepath.Join(home, "os-release")
	if err := os.WriteFile(osRelease, []byte("ID=arch\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	opts := Options{
		In:            strings.NewReader(""),
		Out:           &strings.Builder{},
		Getenv:        envFunc(map[string]string{"XDG_CURRENT_DESKTOP": "Hyprland", "SENDA_HOME": "/tmp/dev"}),
		Euid:          1000,
		OSReleasePath: osRelease,
		LookPath:      lookPathFound("qs", "jq", "nmcli", "wpctl", "python3"),
		Pacman:        &fakePacman{},
		ReleasesURL:   "http://127.0.0.1:1",
	}

	err := Run(context.Background(), opts)
	if err == nil || err.Error() != "SENDA_HOME está definido; setup solo instala releases" {
		t.Fatalf("Run() error = %v", err)
	}
}
