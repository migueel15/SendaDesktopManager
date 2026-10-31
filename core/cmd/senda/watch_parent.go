package main

import (
	"os"
	"syscall"
)

// exitWithParent makes a background watcher die with the process that started
// it, even when that process gets no chance to stop it.
func exitWithParent() {
	parent := os.Getppid()
	_, _, _ = syscall.RawSyscall(syscall.SYS_PRCTL, syscall.PR_SET_PDEATHSIG, uintptr(syscall.SIGTERM), 0)
	// The signal is lost if the parent died before it was requested.
	if os.Getppid() != parent {
		os.Exit(0)
	}
}
