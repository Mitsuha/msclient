package tools

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"

	"github.com/mirrorstages/mstages/internal/api"
	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/cert"
)

// codexTool manages ~/.codex: a .env with proxy vars, an auth.json holding
// MirrorStages credentials, and removal of any config.toml provider override.
type codexTool struct {
	fb *fileBackup
}

func (c *codexTool) name() string       { return "codex" }
func (c *codexTool) executable() string { return "codex" }

func (c *codexTool) fileBackup() (*fileBackup, error) {
	if c.fb != nil {
		return c.fb, nil
	}
	dir, err := app.CodexDir()
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	// Move semantics, matching desktop codex_config_backup.dart.
	c.fb = newFileBackup(dir, []string{"auth.json", "config.toml", ".env"}, true)
	return c.fb, nil
}

func (c *codexTool) performBackup() error {
	fb, err := c.fileBackup()
	if err != nil {
		return err
	}
	return fb.Perform()
}

func (c *codexTool) restoreBackup() error {
	fb, err := c.fileBackup()
	if err != nil {
		return err
	}
	return fb.Restore()
}

func (c *codexTool) initialize(ctx context.Context, token string) error {
	dir, err := app.CodexDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	if err := c.writeProxyEnv(dir); err != nil {
		return err
	}
	if err := c.writeAuth(ctx, dir, token); err != nil {
		return err
	}
	return c.clearProviderConfig(dir)
}

// writeProxyEnv merges the lowercase proxy vars into ~/.codex/.env, preserving
// any other entries.
func (c *codexTool) writeProxyEnv(dir string) error {
	path := filepath.Join(dir, ".env")
	env, err := parseEnv(path)
	if err != nil {
		return err
	}
	env["http_proxy"] = app.LocalProxyURL
	env["https_proxy"] = app.LocalProxyURL
	if p, e := cert.Path(); e == nil {
		env["SSL_CERT_FILE"] = p
	}
	return os.WriteFile(path, serializeEnv(env), 0o644)
}

// writeAuth fetches Codex credentials and writes the raw JSON body to auth.json.
func (c *codexTool) writeAuth(ctx context.Context, dir, token string) error {
	client := api.New()
	raw, err := client.CodexAuth(ctx, token, 0)
	if err != nil {
		return err
	}
	// Re-indent for readability, matching the desktop pretty-print.
	var pretty any
	if err := json.Unmarshal(raw, &pretty); err != nil {
		return err
	}
	out, err := json.MarshalIndent(pretty, "", "  ")
	if err != nil {
		return err
	}
	out = append(out, '\n')
	return os.WriteFile(filepath.Join(dir, "auth.json"), out, 0o644)
}

// clearProviderConfig deletes config.toml so Codex falls back to the default
// MirrorStages provider.
func (c *codexTool) clearProviderConfig(dir string) error {
	path := filepath.Join(dir, "config.toml")
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}
