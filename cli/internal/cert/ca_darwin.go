//go:build darwin

package cert

import (
	"bytes"
	"crypto/x509"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// loginKeychain returns ~/Library/Keychains/login.keychain-db.
func loginKeychain() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, "Library", "Keychains", "login.keychain-db"), nil
}

// isTrusted verifies the CA chains to a system-trusted root. `security
// verify-cert` succeeds only when trust settings are in place, so it doubles as
// a trust check.
func isTrusted(cert *x509.Certificate) (bool, error) {
	path, err := writeToDisk()
	if err != nil {
		return false, err
	}
	cmd := exec.Command("/usr/bin/security", "verify-cert", "-c", path, "-p", "basic")
	if err := cmd.Run(); err != nil {
		// Non-zero exit means not trusted; not a hard error.
		return false, nil
	}
	return true, nil
}

// install adds the CA to the login keychain with root trust. This targets the
// user keychain (no sudo), though macOS may present a one-time auth dialog.
func install(cert *x509.Certificate, path string) error {
	keychain, err := loginKeychain()
	if err != nil {
		return err
	}
	cmd := exec.Command("/usr/bin/security", "add-trusted-cert",
		"-r", "trustRoot", "-k", keychain, path)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("trust MirrorStages CA (you can run it manually: "+
			"security add-trusted-cert -r trustRoot -k %q %q): %w: %s",
			keychain, path, err, stderr.String())
	}
	return nil
}
