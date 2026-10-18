package main

import (
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
	"github.com/migueel15/SendaDesktopManager/core/internal/service"
	"github.com/spf13/cobra"
)

const dorlabAPIKeyEnv = "DORLAB_API_KEY"

var shellCmd = &cobra.Command{
	Use:   "shell",
	Short: "Quickshell commands",
}

var shellRunCmd = &cobra.Command{
	Use:   "run",
	Short: "run Quickshell instance",
	RunE: func(cmd *cobra.Command, args []string) error {
		// With the service installed, an interactive run asks systemd to
		// start it, so there is only ever one supervised instance.
		if service.Installed() && !service.RunningUnderSystemd() {
			return service.Start()
		}
		return runShellInteractive()
	},
}

var shellKillCmd = &cobra.Command{
	Use:   "kill",
	Short: "kill Quickshell instance",
	RunE: func(cmd *cobra.Command, args []string) error {
		if service.Installed() {
			if err := service.Stop(); err != nil {
				return err
			}
		}
		// Also stop an instance started by hand, outside the service.
		closeShell()
		return nil
	},
}

var shellRestartCdm = &cobra.Command{
	Use:   "restart",
	Short: "restart quickshell instance",
	RunE: func(cmd *cobra.Command, args []string) error {
		if service.Installed() {
			return service.Restart()
		}
		return restartShell()
	},
}

func init() {
	shellCmd.AddCommand(shellRunCmd)
	shellCmd.AddCommand(shellKillCmd)
	shellCmd.AddCommand(shellRestartCdm)
}

// runShellInteractive runs Quickshell in the foreground until it exits or
// this process receives SIGINT or SIGTERM. It returns an error when Quickshell
// fails on its own, so systemd restarts the service.
func runShellInteractive() error {
	// check if shell already launched
	pid := readPidData()
	if pid > 0 {
		process, err := os.FindProcess(pid)
		if err == nil && process.Signal(syscall.Signal(0)) == nil {
			fmt.Println("Quickshell is already running")
			return nil
		}
	}

	cmd := exec.Command("qs", "-p", paths.QuickshellDir())
	cmd.Env = append(os.Environ(), quickshellEnv()...)

	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("error running shell: %w", err)
	}

	if err := writePidFile(cmd.Process.Pid); err != nil {
		log.Println("Error writing pid file:", err)
	}

	defer removePidFile()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(sigChan)

	done := make(chan error, 1)

	go func() {
		done <- cmd.Wait()
	}()

	select {
	case sig := <-sigChan:
		log.Println("Received signal:", sig)

		if cmd.Process != nil {
			_ = cmd.Process.Signal(syscall.SIGTERM)
		}

		err := <-done
		if err != nil {
			log.Println("Quickshell exited:", err)
		}
		return nil

	case err := <-done:
		if err != nil {
			return fmt.Errorf("quickshell exited: %w", err)
		}
		return nil
	}
}

func closeShell() bool {
	pid := readPidData()
	if pid <= 0 {
		fmt.Println("Quickshell is not running")
		removePidFile()
		return true
	}

	process, err := os.FindProcess(pid)
	if err != nil {
		fmt.Println("error finding quickshell process:", err)
		return false
	}

	if err := process.Signal(syscall.Signal(0)); err != nil {
		if errors.Is(err, syscall.ESRCH) {
			fmt.Println("Quickshell is not running")
			removePidFile()
			return true
		}

		fmt.Println("error checking quickshell process:", err)
		return false
	}

	if err := process.Signal(syscall.SIGTERM); err != nil {
		if errors.Is(err, syscall.ESRCH) {
			removePidFile()
			return true
		}

		fmt.Println("error killing quickshell:", err)
		return false
	}

	if !waitForProcessExit(process, 3*time.Second) {
		fmt.Println("quickshell did not stop in time")
		return false
	}

	removePidFile()
	fmt.Println("proceso terminado")
	return true
}

func restartShell() error {
	if !closeShell() {
		return nil
	}
	return runShellInteractive()
}

func waitForProcessExit(process *os.Process, timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if err := process.Signal(syscall.Signal(0)); errors.Is(err, syscall.ESRCH) || errors.Is(err, os.ErrProcessDone) {
			return true
		}
		time.Sleep(100 * time.Millisecond)
	}

	return false
}

func readPidData() int {
	pidFile := getPidFilePath()
	data, err := os.ReadFile(pidFile)
	if err != nil {
		if !os.IsNotExist(err) {
			fmt.Println("Error reading quickshell pid:", err)
		}
		return -1
	}

	pidStr := strings.TrimSpace(string(data))

	pid, err := strconv.Atoi(pidStr)
	if err != nil || pid <= 0 {
		fmt.Println("Invalid quickshell pid")
		return -1
	}
	return pid
}

func getRuntimedDir() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return runtime
	}
	return os.TempDir()
}

func getPidFilePath() string {
	return filepath.Join(getRuntimedDir(), "senda-quickshell.pid")
}

func writePidFile(childPid int) error {
	pidFile := getPidFilePath()
	return os.WriteFile(pidFile, []byte(strconv.Itoa(childPid)), 0o644)
}

func removePidFile() {
	pidFile := getPidFilePath()
	os.Remove(pidFile)
}

// quickshellEnv exposes the running senda binary to QML and passes the
// private DORLAB_API_KEY from the environment or the config file.
func quickshellEnv() []string {
	var env []string
	if executable, err := os.Executable(); err == nil {
		env = append(env, "SENDA_BIN="+executable)
	}

	if key := paths.Setting(dorlabAPIKeyEnv); key != "" {
		log.Println("loaded", dorlabAPIKeyEnv)
		env = append(env, dorlabAPIKeyEnv+"="+key)
	} else {
		log.Println(dorlabAPIKeyEnv, "not set in the environment or", paths.ConfigFile())
	}
	return env
}
