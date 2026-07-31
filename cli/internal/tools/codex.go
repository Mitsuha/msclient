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

func (c *codexTool) name() string        { return "codex" }
func (c *codexTool) displayName() string { return "Codex" }
func (c *codexTool) executable() string  { return "codex" }

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
	// Cleanup restores every tool, so bail out without creating ~/.codex on a
	// machine that only ever ran the other persona.
	if !hasBackupDir(app.CodexDir) {
		return nil
	}
	fb, err := c.fileBackup()
	if err != nil {
		return err
	}
	return fb.Restore()
}

// account reads ~/.codex/auth.json and reports the configured MirrorStages
// account. The discriminator is the pair of claims MirrorStages puts in the
// access token; a token from a direct ChatGPT login does not carry them.
func (c *codexTool) account() (*accountInfo, error) {
	dir, err := app.CodexDir()
	if err != nil {
		return nil, err
	}
	raw, err := os.ReadFile(filepath.Join(dir, "auth.json"))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	tokens := codexTokens(raw)
	if !codexGrantsMirrorStages(tokens.Access) {
		return nil, nil
	}
	return codexAccount(tokens), nil
}

// requestAccount asks the backend for a fresh Codex account. Nothing is
// written yet, so the caller can still back up the user's original config.
func (c *codexTool) requestAccount(ctx context.Context, token string) (*pendingAccount, error) {
	raw, err := api.New().CodexAuth(ctx, token, 0)
	if err != nil {
		return nil, err
	}
	return &pendingAccount{raw: raw, info: codexAccount(codexTokens(raw))}, nil
}

// writeAccount stores the granted credentials as ~/.codex/auth.json.
func (c *codexTool) writeAccount(pending *pendingAccount) error {
	dir, err := app.CodexDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	return c.writeAuth(dir, pending.raw)
}

// applyProxy points Codex at the loopback proxy and drops any provider
// override so the account credentials are used.
func (c *codexTool) applyProxy() error {
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

// writeAuth writes the granted credentials verbatim to auth.json.
func (c *codexTool) writeAuth(dir string, raw json.RawMessage) error {
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
	if err := os.WriteFile(filepath.Join(dir, "auth.json"), out, 0o644); err != nil {
		return err
	}
	return writeInstallationID(dir, raw)
}

// writeInstallationID mirrors the response's installation_id into a bare
// ~/.codex/installation_id file, matching the desktop client. Codex reads it
// separately from auth.json, and it must survive across account switches.
func writeInstallationID(dir string, authJSON []byte) error {
	var doc struct {
		InstallationID string `json:"installation_id"`
	}
	if err := json.Unmarshal(authJSON, &doc); err != nil || doc.InstallationID == "" {
		return nil
	}
	return os.WriteFile(filepath.Join(dir, "installation_id"), []byte(doc.InstallationID), 0o644)
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
