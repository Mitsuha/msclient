// Package config persists user preferences under ~/.mstages/config.json,
// currently just the selected proxy node URL.
package config

import (
	"encoding/json"
	"os"

	"github.com/mirrorstages/mstages/internal/app"
)

// Config is the on-disk preference file.
type Config struct {
	SelectedNodeURL string `json:"selected_node_url,omitempty"`
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
