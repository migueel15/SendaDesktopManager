package discordbridge

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestStopWithoutBridge(t *testing.T) {
	if err := Stop(filepath.Join(t.TempDir(), "missing.sock"), time.Second); err != nil {
		t.Fatalf("Stop without bridge: %v", err)
	}
}

func TestStopTerminatesListener(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Skip("python3 not available")
	}
	socket := filepath.Join(t.TempDir(), "bridge.sock")
	listener := exec.Command(python, "-c", `import socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.bind(sys.argv[1])
s.listen()
time.sleep(30)`, socket)
	if err := listener.Start(); err != nil {
		t.Fatal(err)
	}
	exited := make(chan struct{})
	go func() {
		listener.Wait()
		close(exited)
	}()
	t.Cleanup(func() { listener.Process.Kill() })

	for i := 0; i < 100; i++ {
		if _, err := os.Stat(socket); err == nil {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}

	if err := Stop(socket, 3*time.Second); err != nil {
		t.Fatalf("Stop: %v", err)
	}
	select {
	case <-exited:
	case <-time.After(3 * time.Second):
		t.Fatal("listener still running")
	}
}
