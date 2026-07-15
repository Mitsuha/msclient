package tools

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"time"
)

// launch runs the downstream tool with stdio passed through, forwarding a
// context cancellation as a graceful termination. It returns the child's exit
// code.
func launch(ctx context.Context, executable string, args []string) (int, error) {
	path, err := exec.LookPath(executable)
	if err != nil {
		return 0, fmt.Errorf("%s not found in PATH: %w", executable, err)
	}

	cmd := exec.Command(path, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()

	if err := cmd.Start(); err != nil {
		return 0, fmt.Errorf("start %s: %w", executable, err)
	}

	waitDone := make(chan error, 1)
	go func() { waitDone <- cmd.Wait() }()

	select {
	case err := <-waitDone:
		return exitCode(err)
	case <-ctx.Done():
		// Parent was asked to terminate; forward it to the child and give it a
		// grace period before killing.
		_ = cmd.Process.Signal(syscall.SIGTERM)
		select {
		case err := <-waitDone:
			return exitCode(err)
		case <-time.After(5 * time.Second):
			_ = cmd.Process.Kill()
			return exitCode(<-waitDone)
		}
	}
}

// exitCode maps a cmd.Wait() error to a process exit code.
func exitCode(err error) (int, error) {
	if err == nil {
		return 0, nil
	}
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode(), nil
	}
	return 0, err
}
