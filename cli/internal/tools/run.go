package tools

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/mirrorstages/mstages/internal/api"
	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/auth"
	"github.com/mirrorstages/mstages/internal/cert"
	"github.com/mirrorstages/mstages/internal/config"
	"github.com/mirrorstages/mstages/internal/models"
	"github.com/mirrorstages/mstages/internal/singbox"
	"github.com/mirrorstages/mstages/internal/tui"
)

// Run executes a persona (mcodex/mclaude) end to end and returns a process exit
// code. Setup failures print to stderr and return 1; otherwise the downstream
// tool's exit code is propagated.
func Run(ctx context.Context, kind Kind) int {
	code, err := runTool(ctx, kind)
	if err != nil {
		fmt.Fprintf(os.Stderr, "mstages: %v\n", err)
		return 1
	}
	return code
}

func runTool(ctx context.Context, kind Kind) (int, error) {
	t := newTool(kind)

	// 1. Require a login session.
	creds, err := auth.Load()
	if err != nil {
		return 0, err
	}

	// 2. Ensure the sing-box binary is present (download with a progress bar).
	binaryPath, err := ensureSingbox(ctx)
	if err != nil {
		return 0, err
	}

	// 3. Ensure the MirrorStages CA is trusted (non-fatal on failure).
	if err := cert.EnsureTrusted(); err != nil {
		fmt.Fprintf(os.Stderr, "mstages: 警告: 证书信任失败: %v\n", err)
	}

	// 4. Start the local sing-box proxy for the selected node.
	proc, err := startProxy(ctx, binaryPath)
	if err != nil {
		return 0, err
	}
	defer proc.Stop()
	status("代理已就绪")

	// 5. Back up the tool's existing config, restoring it on exit.
	if err := t.performBackup(); err != nil {
		return 0, fmt.Errorf("备份 %s 配置: %w", t.name(), err)
	}
	defer func() {
		if err := t.restoreBackup(); err != nil {
			fmt.Fprintf(os.Stderr, "mstages: 恢复 %s 配置失败: %v\n", t.name(), err)
		}
	}()

	// 6. Initialize the tool with MirrorStages credentials + proxy settings.
	if err := t.initialize(ctx, creds.Token); err != nil {
		var apiErr *api.Error
		if errors.As(err, &apiErr) && apiErr.Unauthorized() {
			_ = auth.Clear()
			return 0, fmt.Errorf("登录已失效，请重新运行 `mstages auth login`")
		}
		return 0, fmt.Errorf("初始化 %s: %w", t.name(), err)
	}
	status(fmt.Sprintf("%s 初始化完成，正在启动…", t.name()))

	// 7. Launch the downstream tool with stdio passed through.
	return launch(ctx, t.executable(), os.Args[1:])
}

// ensureSingbox returns the binary path, downloading it (with a TUI progress
// bar) only when missing.
func ensureSingbox(ctx context.Context) (string, error) {
	installed, err := singbox.IsInstalled()
	if err != nil {
		return "", err
	}
	if installed {
		return app.SingboxBinaryPath()
	}
	return tui.DownloadSingbox(ctx)
}

// startProxy fetches the node list, resolves the selected node, and starts
// sing-box.
func startProxy(ctx context.Context, binaryPath string) (*singbox.Process, error) {
	options := fetchNodes(ctx)
	cfg, err := config.Load()
	if err != nil {
		return nil, err
	}
	return singbox.Start(ctx, binaryPath, options, cfg.SelectedNodeURL)
}

// fetchNodes returns the server's node list, falling back to a single default
// node when the API is unreachable.
func fetchNodes(ctx context.Context) []models.ClientProxyOption {
	options, err := api.New().ClientProxyOptions(ctx)
	if err != nil || len(options) == 0 {
		return []models.ClientProxyOption{{Name: "default", URL: app.FallbackProxyURL}}
	}
	return options
}

func status(msg string) {
	fmt.Fprintf(os.Stderr, "  \033[32m✓\033[0m %s\n", msg)
}
