package singbox

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"time"

	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/models"
)

// Process is a running sing-box instance managed by the CLI.
type Process struct {
	cmd     *exec.Cmd
	logFile *os.File
}

// WriteConfig atomically writes the generated config to ~/.mstages/sing-box.json.
func WriteConfig(cfg *Config) error {
	path, err := app.SingboxConfigPath()
	if err != nil {
		return err
	}
	raw, err := json.MarshalIndent(cfg.JSON, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, raw, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// Start generates the config for the given nodes, writes it, launches
// `sing-box run -c <config>`, and blocks until the Clash API answers (or the
// context / a ~15s timeout elapses).
func Start(ctx context.Context, binaryPath string, proxies []models.ClientProxyOption, selectedURL string) (*Process, error) {
	cfg, err := BuildConfig(proxies, selectedURL)
	if err != nil {
		return nil, err
	}
	if err := WriteConfig(cfg); err != nil {
		return nil, err
	}

	configPath, err := app.SingboxConfigPath()
	if err != nil {
		return nil, err
	}
	logPath, err := app.SingboxLogPath()
	if err != nil {
		return nil, err
	}
	logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644)
	if err != nil {
		return nil, err
	}

	cmd := exec.Command(binaryPath, "run", "-c", configPath)
	cmd.Stdout = logFile
	cmd.Stderr = logFile
	if err := cmd.Start(); err != nil {
		logFile.Close()
		return nil, fmt.Errorf("start sing-box: %w", err)
	}

	p := &Process{cmd: cmd, logFile: logFile}
	if err := waitForAPI(ctx); err != nil {
		p.Stop()
		return nil, err
	}
	return p, nil
}

// Stop terminates the process, waiting up to 3s for it to exit.
func (p *Process) Stop() {
	if p == nil || p.cmd == nil || p.cmd.Process == nil {
		return
	}
	_ = p.cmd.Process.Kill()
	done := make(chan struct{})
	go func() { _ = p.cmd.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
	}
	if p.logFile != nil {
		p.logFile.Close()
	}
}

// waitForAPI polls the Clash /version endpoint up to 30× at 500ms.
func waitForAPI(ctx context.Context) error {
	for i := 0; i < 30; i++ {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if ClashHealthy(ctx) {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(500 * time.Millisecond):
		}
	}
	return fmt.Errorf("sing-box Clash API did not become ready in time")
}
