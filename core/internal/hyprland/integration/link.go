package integration

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/hyprctl"
	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

// Link describes whether the running Hyprland has loaded Senda's module.
type Link struct {
	Loaded  bool
	Version string
	// Source is the file the module was loaded from, when Lua reports it.
	Source string
}

// probeExpression returns "missing" or "<version>\t<source>".
var probeExpression = fmt.Sprintf(`type(%[1]s) == "function" and (tostring(%[1]s()) .. "\t" .. debug.getinfo(%[1]s, "S").source) or "missing"`, ProbeFunction)

// InSession reports whether hyprctl can reach a running Hyprland.
func InSession() bool { return hyprctl.InSession() }

// Probe asks the running Hyprland whether the probe function exists. It does
// not depend on how the user organises their configuration files.
func Probe(ctx context.Context, run stt.Runner) (Link, error) {
	text, err := hyprctl.New(run).Repl(ctx, probeExpression)
	if err != nil {
		return Link{}, err
	}
	if text == "missing" {
		return Link{}, nil
	}
	version, source, ok := strings.Cut(text, "\t")
	if !ok {
		return Link{}, fmt.Errorf("respuesta inesperada de hyprctl repl: %q", text)
	}
	return Link{Loaded: true, Version: version, Source: strings.TrimPrefix(source, "@")}, nil
}

// moduleOverride is the module location reported by a loaded module, so that
// regeneration follows the user if they moved Senda's file.
var moduleOverride string

// Locate makes ModulePath follow the file a loaded module came from, when it
// is a regular file carrying Senda's header.
func Locate(link Link) {
	moduleOverride = ""
	if !link.Loaded || !filepath.IsAbs(link.Source) {
		return
	}
	if ok, _ := owned(link.Source, moduleHeader); ok {
		moduleOverride = link.Source
	}
}

func hyprConfigFile() string {
	return filepath.Join(filepath.Dir(paths.ConfigDir()), "hypr", "hyprland.lua")
}

// EnsureLinked loads the module in Hyprland when it is not already loaded. In
// a session the check is the probe function; outside one, the require line in
// hyprland.lua. When missing, the require line is appended at the end of
// hyprland.lua. It returns a warning when the link could not be confirmed.
func EnsureLinked(ctx context.Context, run stt.Runner) (string, error) {
	session := InSession()
	if session {
		link, err := Probe(ctx, run)
		if err != nil {
			return "", err
		}
		if link.Loaded {
			return "", nil
		}
	}
	main := hyprConfigFile()
	info, err := os.Stat(main)
	if errors.Is(err, os.ErrNotExist) {
		return fmt.Sprintf("No existe %s; añade %s a tu configuración de Hyprland.", main, RequireLine), nil
	}
	if err != nil {
		return "", err
	}
	if !info.Mode().IsRegular() {
		return fmt.Sprintf("%s no es un archivo regular; añade %s manualmente.", main, RequireLine), nil
	}
	data, err := os.ReadFile(main)
	if err != nil {
		return "", err
	}
	if !hasRequire(string(data)) {
		text := string(data)
		if text != "" && !strings.HasSuffix(text, "\n") {
			text += "\n"
		}
		text += managedReference + "\n"
		if err := writePreservingMode(main, []byte(text), info.Mode().Perm()); err != nil {
			return "", fmt.Errorf("añadir el módulo a %s: %w", main, err)
		}
	}
	if !session {
		return "", nil
	}
	if err := binds.Reload(ctx, run); err != nil {
		return "No se pudo recargar Hyprland: " + err.Error(), nil
	}
	link, err := Probe(ctx, run)
	if err != nil {
		return "", err
	}
	if !link.Loaded {
		return fmt.Sprintf("Hyprland no ha cargado el módulo de Senda; comprueba que %s llega a ejecutar %s.", main, RequireLine), nil
	}
	return "", nil
}

func hasRequire(text string) bool {
	for _, line := range strings.Split(text, "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), RequireLine) {
			return true
		}
	}
	return false
}
