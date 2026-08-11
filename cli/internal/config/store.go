// Package config persists user preferences under ~/.mstages/config.json:
// the selected proxy node URL and the pack tool usage is billed against.
package config

import (
	"encoding/json"
	"os"

	"github.com/mirrorstages/mstages/internal/app"
)

// PayAsYouGoPackID is the user_pack_id meaning 按量计费 — the default when the
// user has never picked a pack.
const PayAsYouGoPackID = 0

// Config is the on-disk preference file.
type Config struct {
	SelectedNodeURL string `json:"selected_node_url,omitempty"`
	UserPackID      int    `json:"user_pack_id,omitempty"`
}

// Load reads config.json. A missing file yields a zero-value Config.
func Load() (*Config, error) {
	path, err := app.ConfigPath()
	if err != nil {
		return nil, err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &Config{}, nil
		}
		return nil, err
	}
	var cfg Config
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return &Config{}, nil
	}
	return &cfg, nil
}

// Save writes config.json.
func Save(cfg *Config) error {
	path, err := app.ConfigPath()
	if err != nil {
		return err
	}
	raw, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, raw, 0o644)
}

// SelectNode persists the chosen node URL.
func SelectNode(url string) error {
	cfg, err := Load()
	if err != nil {
		return err
	}
	cfg.SelectedNodeURL = url
	return Save(cfg)
}

// SelectPack persists the pack to bill against. PayAsYouGoPackID restores
// 按量计费. The change takes effect the next time a persona requests an
// account; a tool already configured with another pack is re-issued then.
func SelectPack(userPackID int) error {
	cfg, err := Load()
	if err != nil {
		return err
	}
	cfg.UserPackID = userPackID
	return Save(cfg)
}
