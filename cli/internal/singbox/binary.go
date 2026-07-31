package singbox

import (
	"context"
	"fmt"
	"os"
	"runtime"

	"github.com/mirrorstages/mstages/internal/app"
	dl "github.com/mirrorstages/mstages/internal/download"
)

// minBinarySize rejects truncated downloads, matching the desktop guard.
const minBinarySize = 1 << 20 // 1 MiB

// ProgressFunc reports download progress. total is -1 when the server does not
// send a Content-Length.
type ProgressFunc func(downloaded, total int64)

// IsInstalled reports whether the sing-box binary already exists on disk.
func IsInstalled() (bool, error) {
	path, err := app.SingboxBinaryPath()
	if err != nil {
		return false, err
	}
	_, err = os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

// EnsureInstalled downloads the sing-box binary when missing and returns its
// path. progress may be nil.
func EnsureInstalled(ctx context.Context, progress ProgressFunc) (string, error) {
	path, err := app.SingboxBinaryPath()
	if err != nil {
		return "", err
	}
	if _, err := os.Stat(path); err == nil {
		return path, nil
	} else if !os.IsNotExist(err) {
		return "", err
	}

	url := app.SingboxDownloadBaseURL + "/" + app.SingboxAssetName()
	if err := download(ctx, url, path, progress); err != nil {
		return "", err
	}
	return path, nil
}

func download(ctx context.Context, url, target string, progress ProgressFunc) error {
	written, err := dl.File(ctx, url, target, dl.ProgressFunc(progress))
	if err != nil {
		return err
	}
	if written < minBinarySize {
		os.Remove(target)
		return fmt.Errorf("downloaded sing-box is too small to be valid (%d bytes)", written)
	}
	if runtime.GOOS != "windows" {
		if err := os.Chmod(target, 0o755); err != nil {
			return fmt.Errorf("chmod: %w", err)
		}
	}
	return nil
}
