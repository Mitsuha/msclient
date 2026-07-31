package singbox

import (
	"context"
	"os"
	"syscall"
	"time"

	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/models"
	"github.com/mirrorstages/mstages/internal/procs"
)

// EnsureRunning makes sure a sing-box instance is serving the loopback proxy.
//
// One instance is shared by every mstages process on the machine. There is no
// lock and no reference count: liveness is decided by probing the Clash API. It
// reports whether this call is the one that started the process.
//
// When two processes race, both see a dead proxy and both spawn sing-box; the
// loser cannot bind port 18610 and exits on its own. That is why a failed start
// re-probes instead of surfacing the error — if the winner's instance is up, we
// are just as well served by it.
func EnsureRunning(ctx context.Context, binaryPath string, proxies []models.ClientProxyOption, selectedURL string) (bool, error) {
	if ClashHealthy(ctx) {
		// Reuse as-is. Do not rewrite sing-box.json: another process may have
		// switched nodes, and overwriting would revert its choice.
		return false, nil
	}

	proc, err := Start(ctx, binaryPath, proxies, selectedURL)
	if err != nil {
		if ClashHealthy(ctx) {
			return false, nil
		}
		return false, err
	}
	// Nobody holds the handle for the process lifetime — cleanup finds it by
	// pid later — so reap it in the background to avoid leaving a zombie.
	proc.Release()
	return true, nil
}

// Release detaches from the process, reaping it in the background so it can
// outlive this mstages instance without becoming a zombie.
func (p *Process) Release() {
	if p == nil || p.cmd == nil {
		return
	}
	cmd, logFile := p.cmd, p.logFile
	p.cmd, p.logFile = nil, nil
	go func() {
		_ = cmd.Wait()
		if logFile != nil {
			logFile.Close()
		}
	}()
}

// StopShared terminates the shared sing-box instance, whichever process
// started it. Callers must first confirm no other mstages process is running.
func StopShared() {
	binaryPath, err := app.SingboxBinaryPath()
	if err != nil {
		return
	}
	pids := procs.FindByExecutable(binaryPath)
	for _, pid := range pids {
		proc, err := os.FindProcess(pid)
		if err != nil {
			continue
		}
		_ = proc.Signal(syscall.SIGTERM)
	}
	if len(pids) == 0 {
		return
	}

	// Give it a moment to shut down cleanly, then insist.
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if len(procs.FindByExecutable(binaryPath)) == 0 {
			return
		}
		time.Sleep(200 * time.Millisecond)
	}
	for _, pid := range procs.FindByExecutable(binaryPath) {
		if proc, err := os.FindProcess(pid); err == nil {
			_ = proc.Kill()
		}
	}
}
