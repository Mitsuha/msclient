//go:build windows

package tools

import (
	"os"
	"os/signal"
)

// ignoreTerminalSignals ignores Ctrl-C while the downstream tool runs. Windows
// has no SIGTSTP/SIGQUIT equivalent, so only os.Interrupt applies.
func ignoreTerminalSignals() func() {
	signal.Ignore(os.Interrupt)
	return func() { signal.Reset(os.Interrupt) }
}
