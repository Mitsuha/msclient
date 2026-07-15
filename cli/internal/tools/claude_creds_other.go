//go:build !darwin

package tools

import (
	"os"
	"path/filepath"

	"github.com/mirrorstages/mstages/internal/app"
)

// On Linux/Windows, Claude Code stores credentials in ~/.claude/.credentials.json.
func credentialsFilePath() (string, error) {
	dir, err := app.ClaudeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, ".credentials.json"), nil
}

func readClaudeCredentials() (string, bool, error) {
	path, err := credentialsFilePath()
	if err != nil {
		return "", false, err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return "", false, nil
		}
		return "", false, err
	}
	return string(raw), true, nil
}

func writeClaudeCredentials(content string) error {
	path, err := credentialsFilePath()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0o600)
}

func deleteClaudeCredentials() error {
	path, err := credentialsFilePath()
	if err != nil {
		return err
	}
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}
