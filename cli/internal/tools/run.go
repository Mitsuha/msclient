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
	"github.com/mirrorstages/mstages/internal/procs"
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

// runTool walks the five stages of a persona launch. Several mstages processes
// share one machine, so every stage checks what already exists before creating
// anything, and teardown only happens for the last one standing.
func runTool(ctx context.Context, kind Kind) (int, error) {
	t := newTool(kind)

	creds, err := auth.Load()
	if err != nil {
		return 0, err
	}

	// Install and trust before the timeline opens: both may print a progress
	// bar or a warning, which would collide with the spinner's redraws.
	binaryPath, err := ensureSingbox(ctx)
	if err != nil {
		return 0, err
	}
	if err := cert.EnsureTrusted(); err != nil {
		fmt.Fprintf(os.Stderr, "mstages: 警告: 证书信任失败: %v\n", err)
	}

	tl := tui.NewTimeline("MirrorStages")

	// 1. Proxy service: start only if nothing is already serving.
	if err := startService(ctx, tl, binaryPath); err != nil {
		tl.Fail()
		return 0, err
	}

	// 2-3. Account: reuse the one already on disk, or request a new one and
	// back up what it replaces.
	if err := ensureAccount(ctx, tl, t, creds.Token); err != nil {
		tl.Fail()
		return 0, err
	}

	// 4. Hand the terminal to the tool. Nothing is printed from here on.
	tl.Finish("正在启动 " + t.displayName())
	code, err := launch(ctx, t.executable(), os.Args[1:])
	if err != nil {
		return 0, err
	}

	// 5. Tear down only if we are the last mstages process on the machine.
	cleanup()
	return code, nil
}

// startService makes sure the loopback proxy is up. The node reads the same
// either way: from the user's point of view the service is starting whether
// this process launched it or merely found it already running.
func startService(ctx context.Context, tl *tui.Timeline, binaryPath string) error {
	tl.Start("正在启动服务")

	cfg, err := config.Load()
	if err != nil {
		return err
	}
	if _, err := singbox.EnsureRunning(ctx, binaryPath, fetchNodes(ctx), cfg.SelectedNodeURL); err != nil {
		return err
	}
	tl.Done("服务已就绪")
	return nil
}

// ensureAccount reuses the MirrorStages account already configured for the
// tool, or requests a new one. Only the "new account" path touches the user's
// original config, and only that path backs it up — backing up on every launch
// would snapshot our own config over the user's after the first run.
//
// An account is only reusable when it bills against the pack the user picked
// with `mstages switch billing`; otherwise a fresh one is requested, which is
// how a billing switch takes effect.
func ensureAccount(ctx context.Context, tl *tui.Timeline, t tool, token string) error {
	tl.Start("正在获取账号")

	cfg, err := config.Load()
	if err != nil {
		return err
	}

	existing, err := t.account()
	if err != nil {
		return err
	}

	if existing != nil && existing.UserPackID == cfg.UserPackID {
		tl.Done("使用账号")
		printAccount(tl, existing)
		return t.applyProxy()
	}

	pending, err := t.requestAccount(ctx, token, cfg.UserPackID)
	if err != nil {
		return accountError(t, err)
	}
	tl.Done("已申请到账号")
	printAccount(tl, pending.info)

	// 3. Back up before the first overwrite.
	tl.Start("正在备份配置")
	if err := t.performBackup(); err != nil {
		return fmt.Errorf("备份 %s 配置: %w", t.name(), err)
	}
	tl.Done("配置已备份")

	if err := t.writeAccount(pending); err != nil {
		return fmt.Errorf("写入 %s 账号: %w", t.name(), err)
	}
	return t.applyProxy()
}

// accountError translates the two backend failures worth explaining.
func accountError(t tool, err error) error {
	var apiErr *api.Error
	if errors.As(err, &apiErr) {
		switch {
		case apiErr.Unauthorized():
			_ = auth.Clear()
			return fmt.Errorf("登录已失效，请重新运行 `mstages auth login`")
		case apiErr.NoAvailableAccount():
			return fmt.Errorf("账号池暂无可用账号，请联系客服补号")
		}
	}
	return fmt.Errorf("申请 %s 账号: %w", t.name(), err)
}

// cleanup restores every tool's original config and stops the shared proxy,
// but only when no other mstages process is left. Another live session would
// otherwise lose its proxy and its credentials mid-run.
//
// Restore covers both tools, not just this persona's: a machine that ran
// mcodex once would otherwise keep a stale ~/.codex/old_configs forever.
func cleanup() {
	if procs.OthersRunning() {
		return
	}
	for _, t := range allTools() {
		if err := t.restoreBackup(); err != nil {
			fmt.Fprintf(os.Stderr, "mstages: 恢复 %s 配置失败: %v\n", t.name(), err)
		}
	}
	singbox.StopShared()
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

// fetchNodes returns the server's node list, falling back to a single default
// node when the API is unreachable.
func fetchNodes(ctx context.Context) []models.ClientProxyOption {
	options, err := api.New().ClientProxyOptions(ctx)
	if err != nil || len(options) == 0 {
		return []models.ClientProxyOption{{Name: "default", URL: app.FallbackProxyURL}}
	}
	return options
}

// printAccount hangs the account's identity off the timeline's last node.
// Tokens are never printed.
func printAccount(tl *tui.Timeline, info *accountInfo) {
	if info == nil {
		return
	}
	tl.Details(
		[2]string{"邮箱", info.Email},
		[2]string{"用户名", info.Username},
		[2]string{"套餐", info.Plan},
	)
}
