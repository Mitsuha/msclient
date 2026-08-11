package tools

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"

	"github.com/mirrorstages/mstages/internal/api"
	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/cert"
)

// codexTool manages ~/.codex: a .env with proxy vars, an auth.json holding
// MirrorStages credentials, and a config.toml stripped of provider overrides.
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
	// Move semantics, matching desktop codex_config_backup.dart — except for
	// config.toml, which is edited key by key and so has to stay in place.
	c.fb = newFileBackup(dir, []string{"auth.json", "config.toml", ".env"}, true).
		keepInPlace("config.toml")
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
func (c *codexTool) requestAccount(ctx context.Context, token string, userPackID int) (*pendingAccount, error) {
	raw, err := api.New().CodexAuth(ctx, token, userPackID)
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

// applyProxy points Codex at the loopback proxy and drops the provider
// override keys so the account credentials are used.
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
	return c.pruneProviderConfig(dir)
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

// managedTOMLKeys are the config.toml assignments that would override the
// account credentials or the model MirrorStages serves. Everything else in the
// file is the user's and is written back untouched.
var managedTOMLKeys = map[string]bool{
	"model_provider":           true,
	"model":                    true,
	"model_reasoning_effort":   true,
	"disable_response_storage": true,
}

// pruneProviderConfig drops the managed keys from config.toml so Codex falls
// back to the default MirrorStages provider, keeping the rest of the user's
// settings. The original file is restored wholesale on exit.
func (c *codexTool) pruneProviderConfig(dir string) error {
	path := filepath.Join(dir, "config.toml")
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	pruned := pruneTOMLKeys(string(raw))
	if pruned == string(raw) {
		return nil
	}
	return os.WriteFile(path, []byte(pruned), 0o644)
}

// pruneTOMLKeys removes whole lines assigning a managed key. The parse is
// deliberately shallow — split each line on its first "=" — but it does track
// table headers, so a `model = …` inside the user's own [model_providers.x]
// table is left alone; only top-level assignments are ours to remove.
func pruneTOMLKeys(content string) string {
	lines := strings.Split(content, "\n")
	kept := make([]string, 0, len(lines))
	topLevel := true
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") {
			topLevel = false
		}
		if topLevel && !strings.HasPrefix(trimmed, "#") {
			if key, _, ok := strings.Cut(trimmed, "="); ok && managedTOMLKeys[strings.TrimSpace(key)] {
				continue
			}
		}
		kept = append(kept, line)
	}
	return strings.Join(kept, "\n")
}
