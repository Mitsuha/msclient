package cert

import (
	"github.com/mirrorstages/mstages/assets"
	"github.com/mirrorstages/mstages/internal/app"
	"os"
	"path/filepath"
)

// EnsureTrusted writes the embedded CA as a regular file only. Failure is
// returned to the caller, which treats it as a warning.
func EnsureTrusted() error {
	dir, err := app.DataDir()
	if err != nil {
		return err
	}
	path := filepath.Join(dir, "ms.cer")
	if err := os.WriteFile(path, assets.RootCA, 0644); err != nil {
		return err
	}
	return nil
}

// writeToDisk is retained for platform build compatibility.
func writeToDisk() (string, error) {
	if err := EnsureTrusted(); err != nil {
		return "", err
	}
	return Path()
}

func Path() (string, error) {
	dir, err := app.DataDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "ms.cer"), nil
}
