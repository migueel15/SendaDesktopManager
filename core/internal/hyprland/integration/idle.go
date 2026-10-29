package integration

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

// ApplyIdle manages only an instance that this function started and whose
// PID and Linux process start time still match. Other instances are untouched.
func ApplyIdle() string {
	if !InSession() || os.Getenv("WAYLAND_DISPLAY") == "" {
		return "hypridle no se ha iniciado: no se ha detectado una sesión Wayland de Hyprland."
	}
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if !filepath.IsAbs(runtime) {
		return "hypridle no se ha iniciado: XDG_RUNTIME_DIR no está disponible."
	}
	info, err := os.Stat(runtime)
	if err != nil || !info.IsDir() {
		return "hypridle no se ha iniciado: XDG_RUNTIME_DIR no está disponible."
	}
	st, ok := info.Sys().(*syscall.Stat_t)
	if !ok || int(st.Uid) != os.Getuid() {
		return "hypridle no se ha iniciado: el directorio de ejecución no pertenece al usuario."
	}
	dir := filepath.Join(runtime, "senda")
	if err := os.MkdirAll(dir, 0700); err != nil {
		return "No se pudo preparar hypridle: " + err.Error()
	}
	lock, err := os.OpenFile(filepath.Join(dir, "hypridle.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return "No se pudo bloquear la gestión de hypridle: " + err.Error()
	}
	defer lock.Close()
	if err = unix.Flock(int(lock.Fd()), unix.LOCK_EX); err != nil {
		return "No se pudo bloquear la gestión de hypridle: " + err.Error()
	}
	defer unix.Flock(int(lock.Fd()), unix.LOCK_UN)
	processes, err := IdleProcesses("/proc", os.Getuid(), IdlePath())
	if err != nil {
		return "No se pudo inspeccionar hypridle: " + err.Error()
	}
	if processes.External > 0 {
		return "Existe un hypridle independiente; se conserva y debe integrarse manualmente antes de activar el de Senda."
	}
	marker := filepath.Join(dir, "hypridle.pid")
	data, _ := os.ReadFile(marker)
	fields := strings.Fields(string(data))
	managed := false
	pid := 0
	if len(fields) == 2 {
		pid, _ = strconv.Atoi(fields[0])
		if pid > 0 && processStart(pid) == fields[1] && processUsesIdle(pid, IdlePath()) {
			managed = true
		}
	}
	if processes.Own > 0 && (!managed || processes.Own != 1) {
		return "Existe un hypridle con la configuración de Senda que no está gestionado por este proceso; reinícialo manualmente para aplicar los cambios."
	}
	if managed {
		fd, err := unix.PidfdOpen(pid, 0)
		if err != nil {
			return "No se pudo comprobar la instancia de hypridle de Senda: " + err.Error()
		}
		defer unix.Close(fd)
		if processStart(pid) != fields[1] || !processUsesIdle(pid, IdlePath()) {
			return "La instancia de hypridle ha cambiado; no se ha reiniciado."
		}
		if err = unix.PidfdSendSignal(fd, unix.SIGTERM, nil, 0); err != nil {
			return "No se pudo detener hypridle de Senda: " + err.Error()
		}
		poll := []unix.PollFd{{Fd: int32(fd), Events: unix.POLLIN}}
		n, err := unix.Poll(poll, 3000)
		if err != nil || n == 0 {
			return "hypridle de Senda no terminó; no se ha iniciado otra instancia."
		}
	}
	cmd := exec.Command("hypridle", "-c", IdlePath())
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err = cmd.Start(); err != nil {
		return "No se pudo iniciar hypridle de Senda: " + err.Error()
	}
	pid = cmd.Process.Pid
	start := processStart(pid)
	_ = cmd.Process.Release()
	if start == "" {
		return "No se pudo identificar la instancia de hypridle iniciada; comprueba su estado manualmente."
	}
	if err = writePreservingMode(marker, []byte(fmt.Sprintf("%d %s\n", pid, start)), 0600); err != nil {
		return "No se pudo registrar hypridle de Senda; comprueba su estado manualmente: " + err.Error()
	}
	time.Sleep(50 * time.Millisecond)
	if processStart(pid) != start {
		return "hypridle de Senda terminó al arrancar; comprueba su configuración y sus registros."
	}
	return ""
}

func processStart(pid int) string {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return ""
	}
	end := strings.LastIndexByte(string(b), ')')
	if end < 0 {
		return ""
	}
	fields := strings.Fields(string(b[end+1:]))
	if len(fields) < 20 {
		return ""
	}
	return fields[19]
}
func processUsesIdle(pid int, path string) bool {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/cmdline", pid))
	if err != nil {
		return false
	}
	args := strings.Split(strings.TrimRight(string(b), "\x00"), "\x00")
	if len(args) < 3 || filepath.Base(args[0]) != "hypridle" {
		return false
	}
	for i := 1; i+1 < len(args); i++ {
		if (args[i] == "-c" || args[i] == "--config") && args[i+1] == path {
			return true
		}
	}
	return false
}

// StopIdle stops only the instance previously started and recorded by Senda.
func StopIdle() string {
	runtime := os.Getenv("XDG_RUNTIME_DIR")
	if !filepath.IsAbs(runtime) {
		return ""
	}
	dir := filepath.Join(runtime, "senda")
	marker := filepath.Join(dir, "hypridle.pid")
	lock, err := os.OpenFile(filepath.Join(dir, "hypridle.lock"), os.O_RDWR, 0600)
	if os.IsNotExist(err) {
		return ""
	}
	if err != nil {
		return "No se pudo comprobar hypridle de Senda: " + err.Error()
	}
	defer lock.Close()
	if err = unix.Flock(int(lock.Fd()), unix.LOCK_EX); err != nil {
		return "No se pudo bloquear la gestión de hypridle: " + err.Error()
	}
	defer unix.Flock(int(lock.Fd()), unix.LOCK_UN)
	data, err := os.ReadFile(marker)
	if os.IsNotExist(err) {
		return ""
	}
	if err != nil {
		return "No se pudo leer el registro de hypridle: " + err.Error()
	}
	fields := strings.Fields(string(data))
	if len(fields) != 2 {
		return "Registro de hypridle no válido; no se ha detenido ningún proceso."
	}
	pid, err := strconv.Atoi(fields[0])
	if err != nil || pid <= 0 {
		return "Registro de hypridle no válido; no se ha detenido ningún proceso."
	}
	if processStart(pid) != fields[1] || !processUsesIdle(pid, IdlePath()) {
		return ""
	}
	fd, err := unix.PidfdOpen(pid, 0)
	if err != nil {
		return "No se pudo comprobar hypridle de Senda: " + err.Error()
	}
	defer unix.Close(fd)
	if processStart(pid) != fields[1] || !processUsesIdle(pid, IdlePath()) {
		return "La instancia de hypridle ha cambiado; no se ha detenido."
	}
	if err = unix.PidfdSendSignal(fd, unix.SIGTERM, nil, 0); err != nil {
		return "No se pudo detener hypridle de Senda: " + err.Error()
	}
	poll := []unix.PollFd{{Fd: int32(fd), Events: unix.POLLIN}}
	n, err := unix.Poll(poll, 3000)
	if err != nil || n == 0 {
		return "hypridle de Senda no terminó; comprueba su estado manualmente."
	}
	_ = os.Remove(marker)
	return ""
}

// StopExternalIdle stops same-user hypridle instances that do not use Senda's
// configuration. Call it only after the user chose Senda's configuration.
func StopExternalIdle() string {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return "No se pudo inspeccionar hypridle: " + err.Error()
	}
	var failed []string
	for _, entry := range entries {
		pid, err := strconv.Atoi(entry.Name())
		if err != nil {
			continue
		}
		info, err := os.Stat(filepath.Join("/proc", entry.Name()))
		if err != nil {
			continue
		}
		owner, ok := info.Sys().(*syscall.Stat_t)
		if !ok || int(owner.Uid) != os.Getuid() {
			continue
		}
		comm, err := os.ReadFile(filepath.Join("/proc", entry.Name(), "comm"))
		if err != nil || strings.TrimSpace(string(comm)) != "hypridle" || processUsesIdle(pid, IdlePath()) {
			continue
		}
		fd, err := unix.PidfdOpen(pid, 0)
		if err != nil {
			continue
		}
		if err = unix.PidfdSendSignal(fd, unix.SIGTERM, nil, 0); err == nil {
			poll := []unix.PollFd{{Fd: int32(fd), Events: unix.POLLIN}}
			if n, e := unix.Poll(poll, 3000); e != nil || n == 0 {
				failed = append(failed, entry.Name())
			}
		} else {
			failed = append(failed, entry.Name())
		}
		unix.Close(fd)
	}
	if len(failed) > 0 {
		return "No se pudo detener hypridle (PID " + strings.Join(failed, ", ") + "); deténlo manualmente."
	}
	return ""
}
