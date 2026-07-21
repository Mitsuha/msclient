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

// claudeCredsSnapshot records the pre-init credential state for restore.
type claudeCredsSnapshot struct {
	Existed bool   `json:"existed"`
	Content string `json:"content"`
}

// claudeTool manages ~/.claude (settings.json + credentials) and ~/.claude.json
// (profile). Credentials live in the macOS Keychain or a file on other OSes.
type claudeTool struct {
	fb *fileBackup
}

func (c *claudeTool) name() string       { return "claude" }
func (c *claudeTool) executable() string { return "claude" }

func (c *claudeTool) fileBackup() (*fileBackup, error) {
	if c.fb != nil {
		return c.fb, nil
	}
	dir, err := app.ClaudeDir()
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	// settings.json is backed up as a file (copy semantics). Credentials are
	// handled separately because they may live in the Keychain.
	c.fb = newFileBackup(dir, []string{"settings.json"}, false)
	return c.fb, nil
}

func (c *claudeTool) credsSnapshotPath() (string, error) {
	dir, err := app.ClaudeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, backupDirName, ".credentials.snapshot.json"), nil
}

func (c *claudeTool) performBackup() error {
	dir, err := app.ClaudeDir()
	if err != nil {
		return err
	}
	// Recover a backup left by a crashed run before creating a new one.
	if _, err := os.Stat(filepath.Join(dir, backupDirName)); err == nil {
		if err := c.restoreBackup(); err != nil {
			return err
		}
	}

	fb, err := c.fileBackup()
	if err != nil {
		return err
	}
	if err := fb.Perform(); err != nil {
		return err
	}

	// Snapshot credentials into the backup dir.
	content, existed, err := readClaudeCredentials()
	if err != nil {
		return err
	}
	snap := claudeCredsSnapshot{Existed: existed, Content: content}
	raw, err := json.Marshal(snap)
	if err != nil {
		return err
	}
	path, err := c.credsSnapshotPath()
	if err != nil {
		return err
	}
	return os.WriteFile(path, raw, 0o600)
}

func (c *claudeTool) restoreBackup() error {
	// Restore credentials first (before the backup dir is removed).
	if path, err := c.credsSnapshotPath(); err == nil {
		if raw, err := os.ReadFile(path); err == nil {
			var snap claudeCredsSnapshot
			if json.Unmarshal(raw, &snap) == nil {
				if snap.Existed {
					_ = writeClaudeCredentials(snap.Content)
				} else {
					_ = deleteClaudeCredentials()
				}
			}
		}
	}

	fb, err := c.fileBackup()
	if err != nil {
		return err
	}
	return fb.Restore()
}

func (c *claudeTool) initialize(ctx context.Context, token string) error {
	dir, err := app.ClaudeDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	client := api.New()
	raw, err := client.ClaudeAuth(ctx, token, 0)
	if err != nil {
		return err
	}
	var authResp map[string]json.RawMessage
	if err := json.Unmarshal(raw, &authResp); err != nil {
		return err
	}

	if err := c.writeCredentials(authResp); err != nil {
		return err
	}
	if err := c.writeProfile(authResp); err != nil {
		return err
	}
	return c.writeProxySettings(dir)
}

// writeCredentials stores {"claudeAiOauth": ...} in the platform credential store.
func (c *claudeTool) writeCredentials(authResp map[string]json.RawMessage) error {
	oauth, ok := authResp["claudeAiOauth"]
	if !ok {
		oauth = json.RawMessage("null")
	}
	payload, err := json.Marshal(map[string]json.RawMessage{"claudeAiOauth": oauth})
	if err != nil {
		return err
	}
	return writeClaudeCredentials(string(payload))
}

// writeProfile merges identity keys into ~/.claude.json and marks onboarding
// complete, preserving all other keys.
func (c *claudeTool) writeProfile(authResp map[string]json.RawMessage) error {
	path, err := app.ClaudeProfilePath()
	if err != nil {
		return err
	}
	profile := map[string]any{}
	if raw, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(raw, &profile)
	}
	for _, key := range []string{"oauthAccount", "userID", "machineID"} {
		if v, ok := authResp[key]; ok {
			var decoded any
			if json.Unmarshal(v, &decoded) == nil {
				profile[key] = decoded
			}
		}
	}
	profile["hasCompletedOnboarding"] = true

	out, err := json.MarshalIndent(profile, "", "  ")
	if err != nil {
		return err
	}
	out = append(out, '\n')
	return os.WriteFile(path, out, 0o644)
}

// writeProxySettings replaces the env block in settings.json with the proxy
// vars and pins theme/model defaults when absent.
func (c *claudeTool) writeProxySettings(dir string) error {
	path := filepath.Join(dir, "settings.json")
	settings := map[string]any{}
	if raw, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(raw, &settings)
	}
	settings["env"] = map[string]any{
		"HTTPS_PROXY": app.LocalProxyURL,
		"HTTP_PROXY":  app.LocalProxyURL,
	}
	if p, e := cert.Path(); e == nil {
		settings["env"].(map[string]any)["NODE_EXTRA_CA_CERTS"] = p
	}
	if _, ok := settings["theme"]; !ok {
		settings["theme"] = "light"
	}
	if _, ok := settings["model"]; !ok {
		settings["model"] = "opus[1m]"
	}
	out, err := json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return err
	}
	out = append(out, '\n')
	return os.WriteFile(path, out, 0o644)
}
