package integration

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"github.com/migueel15/SendaDesktopManager/core/internal/hyprland/binds"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/version"
)

type Status struct {
	LockShortcut      string   `json:"lockShortcut"`
	DictationShortcut string   `json:"dictationShortcut"`
	IdleSeconds       int      `json:"idleSeconds"`
	Blur              bool     `json:"blur"`
	ModulePath        string   `json:"modulePath"`
	ModuleActive      bool     `json:"moduleActive"`
	IdleConfigPath    string   `json:"idleConfigPath"`
	Warnings          []string `json:"warnings"`
}

func Inspect(ctx context.Context, s Settings, run stt.Runner) Status {
	status := Status{LockShortcut: s.LockShortcut, DictationShortcut: s.DictationShortcut, IdleSeconds: s.IdleSeconds, Blur: s.Blur, ModulePath: ModulePath(), IdleConfigPath: IdlePath(), Warnings: []string{}}
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") != "" {
		if run == nil {
			run = stt.ExecRunner
		}
		out, err := run(ctx, nil, "hyprctl", "repl", `package.loaded["modules.senda"] ~= nil`)
		if err != nil {
			status.Warnings = append(status.Warnings, "No se pudo comprobar si el módulo está cargado: "+err.Error())
		} else {
			status.ModuleActive = strings.TrimSpace(string(out)) == "true"
		}
		for _, pair := range []struct{ label, shortcut string }{{"bloqueo", s.LockShortcut}, {"dictado", s.DictationShortcut}} {
			conflicts, err := binds.Conflicts(ctx, run, pair.shortcut)
			if err != nil {
				status.Warnings = append(status.Warnings, "No se pudieron comprobar conflictos de "+pair.label+": "+err.Error())
				continue
			}
			for _, conflict := range conflicts {
				if pair.label == "bloqueo" && conflict == "Senda lock" {
					continue
				}
				status.Warnings = append(status.Warnings, fmt.Sprintf("Conflicto de %s (%s): %s", pair.label, pair.shortcut, conflict))
			}
		}
	} else {
		status.Warnings = append(status.Warnings, "No hay una sesión de Hyprland detectada; no se han comprobado los atajos activos.")
	}
	if os.Getenv("SENDA_HOME") != "" || version.Version == "dev" {
		status.Warnings = append(status.Warnings, "Se ha detectado un entorno de desarrollo; comprueba que el ejecutable generado sea persistente.")
	}
	if !status.ModuleActive {
		status.Warnings = append(status.Warnings, "Activa el módulo en hyprland.lua con "+RequireLine)
	}
	idle, err := IdleProcesses("/proc", os.Getuid(), IdlePath())
	if err != nil {
		status.Warnings = append(status.Warnings, "No se pudo comprobar hypridle: "+err.Error())
	} else if idle.External > 0 {
		status.Warnings = append(status.Warnings, fmt.Sprintf("Hay %d instancia(s) de hypridle con otra configuración o configuración desconocida; no se modifican. Integra la configuración manualmente antes de ejecutar hypridle -c %q", idle.External, IdlePath()))
	} else if idle.Own == 0 {
		status.Warnings = append(status.Warnings, fmt.Sprintf("hypridle de Senda no está activo; inicia una única instancia con hypridle -c %q", IdlePath()))
	}
	return status
}

type Processes struct{ Own, External int }

// IdleProcesses classifies same-user processes conservatively. Unknown command
// lines count as external; no process is signalled by this inspection.
func IdleProcesses(proc string, uid int, idlePath string) (Processes, error) {
	var result Processes
	entries, err := os.ReadDir(proc)
	if err != nil {
		return result, err
	}
	for _, entry := range entries {
		if _, err := strconv.Atoi(entry.Name()); err != nil || !entry.IsDir() {
			continue
		}
		dir := filepath.Join(proc, entry.Name())
		info, err := os.Stat(dir)
		if err != nil {
			continue
		}
		// /proc/<pid> is owned by the process' effective user.
		owner, ok := info.Sys().(*syscall.Stat_t)
		if !ok || int(owner.Uid) != uid {
			continue
		}
		comm, err := os.ReadFile(filepath.Join(dir, "comm"))
		if err != nil || strings.TrimSpace(string(comm)) != "hypridle" {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(dir, "cmdline"))
		if err != nil {
			result.External++
			continue
		}
		args := strings.Split(strings.TrimRight(string(raw), "\x00"), "\x00")
		config := ""
		for i := 1; i < len(args); i++ {
			if (args[i] == "-c" || args[i] == "--config") && i+1 < len(args) {
				config = args[i+1]
				i++
			} else if strings.HasPrefix(args[i], "--config=") {
				config = strings.TrimPrefix(args[i], "--config=")
			}
		}
		if filepath.IsAbs(config) && filepath.Clean(config) == filepath.Clean(idlePath) {
			result.Own++
		} else {
			result.External++
		}
	}
	return result, nil
}
