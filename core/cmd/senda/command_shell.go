package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	"github.com/spf13/cobra"
)

var path = "/home/miguel/repos/SendaDesktopManager/quickshell/"

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

func init() {
	shellCmd.AddCommand(shellRunCmd)
	shellCmd.AddCommand(shellKillCmd)
}

func runShellInteractive() {
	// check if shell already launched
	pid := readPidData()
	if pid != -1 {
		fmt.Println("Quickshell is already running")
		return
	}

	cmd := exec.Command("qs", "-p", path)

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

func closeShell() {
	pid := readPidData()

	process, err := os.FindProcess(pid)
	if err != nil {
		fmt.Println("error finding pid")
	}
	if err := process.Signal(syscall.SIGTERM); err != nil {
		fmt.Println("error killing quickshell")
		return
	}

	fmt.Println("porceso terminado")
}

func readPidData() int {
	pidFile := getPidFilePath()
	data, err := os.ReadFile(pidFile)
	if err != nil {
		fmt.Println("Error killing quickshell. Pid file not found")
		return -1
	}

	pidStr := strings.TrimSpace(string(data))

	pid, err := strconv.Atoi(pidStr)
	if err != nil {
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
	println(pidFile)
	return os.WriteFile(pidFile, []byte(strconv.Itoa(childPid)), 0o644)
}

func removePidFile() {
	pidFile := getPidFilePath()
	println("Removing", pidFile)
	os.Remove(pidFile)
}
