package main

import (
	"bufio"
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

	"github.com/spf13/cobra"
)

var path = "/home/miguel/repos/SendaDesktopManager/quickshell/"

const dorlabAPIKeyEnv = "DORLAB_API_KEY"

var shellCmd = &cobra.Command{
	Use:   "shell",
	Short: "Quickshell commands",
}

var shellRunCmd = &cobra.Command{
	Use:   "run",
	Short: "run Quickshell instance",
	Run: func(cmd *cobra.Command, args []string) {
		runShellInteractive()
	},
}

var shellKillCmd = &cobra.Command{
	Use:   "kill",
	Short: "kill Quickshell instance",
	Run: func(cmd *cobra.Command, args []string) {
		closeShell()
	},
}

var shellRestartCdm = &cobra.Command{
	Use:   "restart",
	Short: "restart quickshell instance",
	Run: func(cmd *cobra.Command, args []string) {
		restartShell()
	},
}

func init() {
	shellCmd.AddCommand(shellRunCmd)
	shellCmd.AddCommand(shellKillCmd)
	shellCmd.AddCommand(shellRestartCdm)
}

func runShellInteractive() {
	// check if shell already launched
	pid := readPidData()
	if pid > 0 {
		process, err := os.FindProcess(pid)
		if err == nil && process.Signal(syscall.Signal(0)) == nil {
			fmt.Println("Quickshell is already running")
			return
		}
	}

	cmd := exec.Command("qs", "-p", path)
	cmd.Env = append(os.Environ(), loadQuickshellEnv()...)

	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		log.Fatalf("Error running shell: %v", err)
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

	case err := <-done:
		if err != nil {
			log.Println("Quickshell exited:", err)
		}
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

func restartShell() {
	if !closeShell() {
		return
	}
	runShellInteractive()
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

func loadQuickshellEnv() []string {
	dotEnvPath := filepath.Join(filepath.Dir(filepath.Clean(path)), ".env")
	dorlabAPIKey, ok, err := readDotEnvValue(dotEnvPath, dorlabAPIKeyEnv)
	if err != nil {
		if !os.IsNotExist(err) {
			log.Println("error reading .env:", err)
		} else {
			log.Println(".env not found at", dotEnvPath)
		}
		return nil
	}

	if !ok || dorlabAPIKey == "" {
		log.Println(dorlabAPIKeyEnv, "not found in", dotEnvPath)
		return nil
	}

	log.Println("loaded", dorlabAPIKeyEnv, "from", dotEnvPath)
	return []string{dorlabAPIKeyEnv + "=" + dorlabAPIKey}
}

func readDotEnvValue(filePath string, key string) (string, bool, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", false, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		line = strings.TrimPrefix(line, "export ")
		name, value, ok := strings.Cut(line, "=")
		if !ok || strings.TrimSpace(name) != key {
			continue
		}

		return parseDotEnvValue(value), true, nil
	}

	if err := scanner.Err(); err != nil {
		return "", false, err
	}

	return "", false, nil
}

func parseDotEnvValue(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}

	if len(value) >= 2 && value[0] == '\'' && value[len(value)-1] == '\'' {
		return value[1 : len(value)-1]
	}

	if strings.HasPrefix(value, "\"") {
		unquoted, err := strconv.Unquote(value)
		if err == nil {
			return unquoted
		}
	}

	if commentIndex := strings.Index(value, " #"); commentIndex >= 0 {
		value = value[:commentIndex]
	}

	return strings.TrimSpace(value)
}
