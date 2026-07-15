package singbox

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"

	"github.com/mirrorstages/mstages/internal/app"
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
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return fmt.Errorf("create bin directory: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download sing-box: unexpected status %d", resp.StatusCode)
	}

	tmp := target + ".download"
	out, err := os.Create(tmp)
	if err != nil {
		return fmt.Errorf("write temp: %w", err)
	}

	total := resp.ContentLength
	pr := &progressReader{reader: resp.Body, total: total, progress: progress}
	written, copyErr := io.Copy(out, pr)
	closeErr := out.Close()
	if copyErr != nil {
		os.Remove(tmp)
		return fmt.Errorf("write temp: %w", copyErr)
	}
	if closeErr != nil {
		os.Remove(tmp)
		return fmt.Errorf("write temp: %w", closeErr)
	}

	if written < minBinarySize {
		os.Remove(tmp)
		return fmt.Errorf("downloaded sing-box is too small to be valid (%d bytes)", written)
	}

	if err := os.Rename(tmp, target); err != nil {
		os.Remove(tmp)
		return fmt.Errorf("rename: %w", err)
	}

	if runtime.GOOS != "windows" {
		if err := os.Chmod(target, 0o755); err != nil {
			return fmt.Errorf("chmod: %w", err)
		}
	}
	return nil
}

type progressReader struct {
	reader     io.Reader
	total      int64
	downloaded int64
	progress   ProgressFunc
}

func (p *progressReader) Read(b []byte) (int, error) {
	n, err := p.reader.Read(b)
	p.downloaded += int64(n)
	if p.progress != nil && n > 0 {
		p.progress(p.downloaded, p.total)
	}
	return n, err
}
