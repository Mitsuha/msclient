// Package cert installs and verifies trust for the embedded MirrorStages root
// CA, which the upstream proxy uses to TLS-intercept the whitelisted domains.
package cert

import (
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"

	"github.com/mirrorstages/mstages/assets"
	"github.com/mirrorstages/mstages/internal/app"
)

// parsed lazily decodes the embedded PEM certificate.
func parsed() (*x509.Certificate, error) {
	block, _ := pem.Decode(assets.RootCA)
	if block == nil {
		return nil, fmt.Errorf("embedded root CA is not valid PEM")
	}
	return x509.ParseCertificate(block.Bytes)
}

// writeToDisk persists the embedded CA to ~/.mstages/mirrorstages-root-ca.cer
// and returns the path, so platform trust tools have a file to reference.
func writeToDisk() (string, error) {
	dir, err := app.DataDir()
	if err != nil {
		return "", err
	}
	path := filepath.Join(dir, "mirrorstages-root-ca.cer")
	if err := os.WriteFile(path, assets.RootCA, 0o644); err != nil {
		return "", err
	}
	return path, nil
}

// EnsureTrusted installs the CA into the OS trust store if it is not already
// trusted. It is safe to call on every run. On unsupported platforms it returns
// an error carrying the manual-install instructions.
func EnsureTrusted() error {
	cert, err := parsed()
	if err != nil {
		return err
	}
	trusted, err := isTrusted(cert)
	if err != nil {
		return err
	}
	if trusted {
		return nil
	}
	path, err := writeToDisk()
	if err != nil {
		return err
	}
	return install(cert, path)
}
