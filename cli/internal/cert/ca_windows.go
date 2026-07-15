//go:build windows

package cert

import (
	"bytes"
	"crypto/sha1"
	"crypto/x509"
	"encoding/hex"
	"fmt"
	"os/exec"
	"strings"
)

// isTrusted checks the current user's Root store for the CA thumbprint.
func isTrusted(cert *x509.Certificate) (bool, error) {
	sum := sha1.Sum(cert.Raw)
	thumb := strings.ToUpper(hex.EncodeToString(sum[:]))
	cmd := exec.Command("certutil", "-user", "-store", "Root", thumb)
	if err := cmd.Run(); err != nil {
		return false, nil
	}
	return true, nil
}

// install adds the CA to the current user's Root store (no elevation needed).
func install(cert *x509.Certificate, path string) error {
	cmd := exec.Command("certutil", "-user", "-addstore", "-f", "Root", path)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("trust MirrorStages CA (run manually: "+
			"certutil -user -addstore -f Root %q): %w: %s", path, err, stderr.String())
	}
	return nil
}
