//go:build !windows

package singbox

import (
	"os/exec"
	"syscall"
)

// detach puts sing-box in its own session so terminal signals aimed at the
// launching shell never reach it.
func detach(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
}
