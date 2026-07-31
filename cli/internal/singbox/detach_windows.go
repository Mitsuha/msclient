//go:build windows

package singbox

import (
	"os/exec"
	"syscall"
)

// detach gives sing-box its own process group and hides its console window, so
// console control events aimed at the launching shell never reach it.
func detach(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: syscall.CREATE_NEW_PROCESS_GROUP | 0x08000000, // CREATE_NO_WINDOW
	}
}
