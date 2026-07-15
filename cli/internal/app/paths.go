package app

import (
	"os"
	"path/filepath"
	"runtime"
)

// HomeDir resolves the user's home directory, falling back to environment
// variables the way the Flutter side does (HOME / USERPROFILE).
func HomeDir() (string, error) {
	if dir, err := os.UserHomeDir(); err == nil && dir != "" {
		return dir, nil
	}
	if runtime.GOOS == "windows" {
		if p := os.Getenv("USERPROFILE"); p != "" {
			return p, nil
		}
	}
	if p := os.Getenv("HOME"); p != "" {
		return p, nil
	}
	return "", os.ErrNotExist
}

// DataDir returns ~/.mstages, creating it if necessary.
func DataDir() (string, error) {
	home, err := HomeDir()
	if err != nil {
		return "", err
	}
	dir := filepath.Join(home, DataDirName)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	return dir, nil
}

// CredentialsPath returns ~/.mstages/credentials.json.
func CredentialsPath() (string, error) {
	dir, err := DataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "credentials.json"), nil
}

// ConfigPath returns ~/.mstages/config.json (holds the selected node URL).
func ConfigPath() (string, error) {
	dir, err := DataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "config.json"), nil
}

// SingboxBinDir returns ~/.mstages/bin.
func SingboxBinDir() (string, error) {
	dir, err := DataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "bin"), nil
}

// SingboxBinaryPath returns the path to the sing-box binary.
func SingboxBinaryPath() (string, error) {
	bin, err := SingboxBinDir()
	if err != nil {
		return "", err
	}
	name := "sing-box"
	if runtime.GOOS == "windows" {
		name = "sing-box.exe"
	}
	return filepath.Join(bin, name), nil
}

// SingboxConfigPath returns ~/.mstages/sing-box.json.
func SingboxConfigPath() (string, error) {
	dir, err := DataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, SingboxConfigFile), nil
}

// SingboxLogPath returns ~/.mstages/sing-box.log.
func SingboxLogPath() (string, error) {
	dir, err := DataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, SingboxLogFile), nil
}

// CodexDir returns ~/.codex.
func CodexDir() (string, error) {
	home, err := HomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".codex"), nil
}

// ClaudeDir returns ~/.claude.
func ClaudeDir() (string, error) {
	home, err := HomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".claude"), nil
}

// ClaudeProfilePath returns ~/.claude.json (the sibling profile file).
func ClaudeProfilePath() (string, error) {
	home, err := HomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".claude.json"), nil
}

// SingboxAssetName returns the platform-specific download asset name.
func SingboxAssetName() string {
	switch runtime.GOOS {
	case "darwin":
		return "sing-box-darwin"
	case "linux":
		return "sing-box-linux"
	case "windows":
		return "sing-box.exe"
	default:
		return "sing-box-" + runtime.GOOS
	}
}
