package setup

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/migueel15/Zenda/core/internal/hyprland/integration"
	"github.com/migueel15/Zenda/core/internal/paths"
)

const idleUnit = "hypridle.service"

// systemctlUser runs `systemctl --user`; tests replace it.
var systemctlUser = func(args ...string) (string, error) {
	out, err := exec.Command("systemctl", append([]string{"--user"}, args...)...).Output()
	return strings.TrimSpace(string(out)), err
}

// Hooks over the running session; tests replace them.
var (
	stopExternalIdle  = integration.StopExternalIdle
	stopUnmanagedIdle = integration.StopUnmanagedIdle
	idleManaged       = integration.IdleManaged
)

// confirm asks a yes/no question; only "s" accepts, so no answer changes nothing.
func confirm(in *bufio.Reader, out io.Writer, question string) bool {
	fmt.Fprint(out, question+" [s/N] ")
	line, _ := in.ReadString('\n')
	return strings.EqualFold(strings.TrimSpace(line), "s")
}

// resolveIdleConflicts offers to remove whatever would run another hypridle
// next to Zenda's: the systemd unit, autostart lines in the Hyprland
// configuration and running instances. accepted skips the question for running
// external instances when the user has just chosen Zenda's configuration.
// It returns warnings for what was left untouched or failed.
func resolveIdleConflicts(in *bufio.Reader, out io.Writer, accepted, session bool) []string {
	var warnings []string
	if w := resolveIdleUnit(in, out); w != "" {
		warnings = append(warnings, w)
	}
	warnings = append(warnings, resolveIdleAutostart(in, out)...)
	if !session {
		return warnings
	}
	procs, err := idleProcesses("/proc", os.Getuid(), integration.IdlePath())
	if err != nil {
		return append(warnings, "No se pudo inspeccionar hypridle: "+err.Error())
	}
	if procs.External > 0 {
		if accepted || confirm(in, out, fmt.Sprintf("Hay %d hypridle con otra configuración en ejecución. ¿Cerrarlo y arrancar el de Zenda?", procs.External)) {
			if w := stopExternalIdle(); w != "" {
				warnings = append(warnings, w)
			}
		}
	}
	if procs.Own > 0 && (procs.Own != 1 || !idleManaged()) {
		if confirm(in, out, "Hay un hypridle con la configuración de Zenda que Zenda no gestiona. ¿Reiniciarlo para que lo gestione Zenda?") {
			if w := stopUnmanagedIdle(); w != "" {
				warnings = append(warnings, w)
			}
		}
	}
	return warnings
}

// resolveIdleUnit offers to stop and disable a systemd user unit for hypridle,
// which would otherwise restart it or start it on the next login.
func resolveIdleUnit(in *bufio.Reader, out io.Writer) string {
	active, _ := systemctlUser("is-active", idleUnit)
	enabled, _ := systemctlUser("is-enabled", idleUnit)
	isActive := active == "active" || active == "activating"
	isEnabled := enabled == "enabled" || enabled == "enabled-runtime"
	if !isActive && !isEnabled {
		return ""
	}
	fmt.Fprintf(out, "systemd gestiona hypridle (%s: %s, %s).\n", idleUnit, active, enabled)
	if !confirm(in, out, "¿Parar y deshabilitar "+idleUnit+" para que lo gestione Zenda?") {
		return idleUnit + " sigue activo; puede ejecutar otro hypridle junto al de Zenda."
	}
	if _, err := systemctlUser("disable", "--now", idleUnit); err != nil {
		return "No se pudo deshabilitar " + idleUnit + ": " + err.Error()
	}
	fmt.Fprintln(out, idleUnit+" parado y deshabilitado.")
	return ""
}

// idleAutostart matches an uncommented line that starts hypridle.
var idleAutostart = regexp.MustCompile(`exec.*\bhypridle\b`)

type autostartLine struct {
	path   string
	number int
	text   string
}

// findIdleAutostart lists lines in the user's Hyprland configuration, outside
// Zenda's generated folder, that start hypridle.
func findIdleAutostart() []autostartLine {
	hypr := filepath.Join(filepath.Dir(paths.ConfigDir()), "hypr")
	zendaDir := integration.Dir()
	var found []autostartLine
	_ = filepath.WalkDir(hypr, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			if p == zendaDir {
				return filepath.SkipDir
			}
			return nil
		}
		if !d.Type().IsRegular() || (!strings.HasSuffix(p, ".lua") && !strings.HasSuffix(p, ".conf")) {
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return nil
		}
		for i, line := range strings.Split(string(b), "\n") {
			t := strings.TrimSpace(line)
			if strings.HasPrefix(t, "#") || strings.HasPrefix(t, "--") || strings.Contains(t, integration.IdlePath()) {
				continue
			}
			if idleAutostart.MatchString(t) {
				found = append(found, autostartLine{p, i + 1, t})
			}
		}
		return nil
	})
	return found
}

// resolveIdleAutostart offers to comment out the lines found by
// findIdleAutostart, with `--` in Lua files and `#` in .conf files.
func resolveIdleAutostart(in *bufio.Reader, out io.Writer) []string {
	found := findIdleAutostart()
	if len(found) == 0 {
		return nil
	}
	fmt.Fprintln(out, "Tu configuración de Hyprland arranca otro hypridle:")
	for _, l := range found {
		fmt.Fprintf(out, "  %s:%d: %s\n", l.path, l.number, l.text)
	}
	if !confirm(in, out, "¿Comentar estas líneas para que solo arranque el de Zenda?") {
		return []string{"Tu configuración de Hyprland sigue arrancando otro hypridle; quítalo para no ejecutar dos instancias."}
	}
	byFile := map[string][]int{}
	for _, l := range found {
		byFile[l.path] = append(byFile[l.path], l.number)
	}
	var warnings []string
	for path, numbers := range byFile {
		info, err := os.Stat(path)
		if err != nil {
			warnings = append(warnings, "No se pudo modificar "+path+": "+err.Error())
			continue
		}
		b, err := os.ReadFile(path)
		if err != nil {
			warnings = append(warnings, "No se pudo modificar "+path+": "+err.Error())
			continue
		}
		marker := "# "
		if strings.HasSuffix(path, ".lua") {
			marker = "-- "
		}
		lines := strings.Split(string(b), "\n")
		for _, n := range numbers {
			line := lines[n-1]
			indent := line[:len(line)-len(strings.TrimLeft(line, " \t"))]
			lines[n-1] = indent + marker + strings.TrimLeft(line, " \t")
		}
		if err := os.WriteFile(path, []byte(strings.Join(lines, "\n")), info.Mode().Perm()); err != nil {
			warnings = append(warnings, "No se pudo modificar "+path+": "+err.Error())
			continue
		}
		fmt.Fprintln(out, "Comentado el arranque de hypridle en", path)
	}
	return warnings
}
