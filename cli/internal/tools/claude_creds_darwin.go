//go:build darwin

package tools

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// On macOS, Claude Code stores its credentials in the login Keychain as a
// generic-password item, matching desktop claude_config_manager.dart.
const (
	keychainService = "Claude Code-credentials"
)

func keychainAccount() string {
	if u := os.Getenv("USER"); u != "" {
		return u
	}
	return "claude"
}

// readClaudeCredentials returns the stored credential blob and whether it
// exists.
func readClaudeCredentials() (string, bool, error) {
	cmd := exec.Command("/usr/bin/security", "find-generic-password",
		"-a", keychainAccount(), "-s", keychainService, "-w")
	var out, errBuf bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errBuf
	if err := cmd.Run(); err != nil {
		// Item not found is not an error for our purposes.
		return "", false, nil
	}
	return strings.TrimRight(out.String(), "\n"), true, nil
}

// writeClaudeCredentials replaces the keychain item, adding -A so any app may
// read it without prompting.
func writeClaudeCredentials(content string) error {
	// Delete first; add-generic-password refuses to overwrite.
	_ = exec.Command("/usr/bin/security", "delete-generic-password",
		"-a", keychainAccount(), "-s", keychainService).Run()

	cmd := exec.Command("/usr/bin/security", "add-generic-password",
		"-a", keychainAccount(), "-s", keychainService, "-w", content, "-A")
	var errBuf bytes.Buffer
	cmd.Stderr = &errBuf
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("write claude keychain credentials: %w: %s", err, errBuf.String())
	}
	return nil
}

// deleteClaudeCredentials removes the keychain item.
func deleteClaudeCredentials() error {
	_ = exec.Command("/usr/bin/security", "delete-generic-password",
		"-a", keychainAccount(), "-s", keychainService).Run()
	return nil
}
