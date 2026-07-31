// Package download fetches a file over HTTP into a local path. Every transfer
// lands on a temporary file next to the target and is renamed into place, so an
// interrupted download never leaves a half-written binary behind.
package download

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
)

// ProgressFunc reports transfer progress. total is -1 when the server does not
// send a Content-Length.
type ProgressFunc func(downloaded, total int64)

// File downloads url to target and returns the number of bytes written.
// progress may be nil. The caller decides whether the size is plausible and
// whether the file needs an executable bit.
func File(ctx context.Context, url, target string, progress ProgressFunc) (int64, error) {
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return 0, fmt.Errorf("create directory: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("下载 %s 失败：HTTP %d", url, resp.StatusCode)
	}

	tmp := target + ".download"
	out, err := os.Create(tmp)
	if err != nil {
		return 0, fmt.Errorf("write temp: %w", err)
	}

	pr := &progressReader{reader: resp.Body, total: resp.ContentLength, progress: progress}
	written, copyErr := io.Copy(out, pr)
	closeErr := out.Close()
	if copyErr != nil || closeErr != nil {
		os.Remove(tmp)
		if copyErr != nil {
			return 0, fmt.Errorf("write temp: %w", copyErr)
		}
		return 0, fmt.Errorf("write temp: %w", closeErr)
	}

	if err := os.Rename(tmp, target); err != nil {
		os.Remove(tmp)
		return 0, fmt.Errorf("rename: %w", err)
	}
	return written, nil
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
