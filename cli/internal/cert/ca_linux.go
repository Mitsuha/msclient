//go:build linux

package cert

import (
	"bytes"
	"crypto/x509"
	"fmt"
	"os"
	"os/exec"
)

const linuxTrustPath = "/usr/local/share/ca-certificates/mirrorstages-root-ca.crt"

// isTrusted checks whether the CA has been copied into the local trust anchor
// directory.
func isTrusted(cert *x509.Certificate) (bool, error) {
	if _, err := os.Stat(linuxTrustPath); err == nil {
		return true, nil
	} else if !os.IsNotExist(err) {
		return false, err
	}
	return false, nil
}

// install copies the CA into the system trust anchors and refreshes the bundle.
// This needs root; on failure the manual commands are surfaced.
func install(cert *x509.Certificate, path string) error {
	if err := copyFile(path, linuxTrustPath); err != nil {
		return manualInstructions(path, err)
	}
	cmd := exec.Command("update-ca-certificates")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%w: %s", manualInstructions(path, err), stderr.String())
	}
	return nil
}

func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0o644)
}

func manualInstructions(path string, cause error) error {
	return fmt.Errorf("trust MirrorStages CA (run as root: "+
		"sudo cp %q %s && sudo update-ca-certificates): %w",
		path, linuxTrustPath, cause)
}
