//go:build !windows

package tools

import (
	"os"
	"os/signal"
	"syscall"
)

// ignoreTerminalSignals makes this process ignore the job-control signals the
// terminal sends to the whole foreground group while the downstream tool runs.
// The returned function restores the default handling.
func ignoreTerminalSignals() func() {
	sigs := []os.Signal{os.Interrupt, syscall.SIGQUIT, syscall.SIGTSTP}
	signal.Ignore(sigs...)
	return func() { signal.Reset(sigs...) }
}
