//go:build !darwin && !linux && !windows

package cert

import (
	"crypto/x509"
	"fmt"
	"runtime"
)

func isTrusted(cert *x509.Certificate) (bool, error) {
	return false, nil
}

func install(cert *x509.Certificate, path string) error {
	return fmt.Errorf("automatic CA trust is not supported on %s; "+
		"please trust %q manually", runtime.GOOS, path)
}
