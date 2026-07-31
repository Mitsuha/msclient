// Package update keeps the CLI current against the release manifest published
// at latest/version.json — the same manifest packaging/install.sh reads.
//
// The install layout is install.sh's: every version lives in its own directory
// under ~/.local/share/mstages/versions, and ~/.local/bin holds one symlink per
// persona pointing at the active one. Updating therefore means dropping in a
// new version directory and re-pointing three symlinks; the currently running
// binary is never overwritten, which is what makes the update safe to do from
// inside that very binary.
package update

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/mirrorstages/mstages/internal/app"
	dl "github.com/mirrorstages/mstages/internal/download"
)

// checkTimeout bounds the startup check. Every launch pays it at most once, so
// it stays short enough not to be felt; a slow or blocked network simply means
// no update this time.
const checkTimeout = 3 * time.Second

// minBinarySize rejects a truncated download, mirroring the guard install.sh
// and the sing-box downloader use.
const minBinarySize = 1 << 20 // 1 MiB

// Manifest is the subset of latest/version.json the CLI needs.
//
// The CLI and the desktop app are versioned and gated separately: cli_version /
// cli_forced are ours, version / forced belong to the GUI. Older manifests only
// carry the GUI pair, so those are the fallback.
type Manifest struct {
	Version    string `json:"version"`
	CLIVersion string `json:"cli_version"`
	Forced     bool   `json:"forced"`
	// CLIForced is a pointer so an absent key falls back to Forced rather than
	// silently reading as false.
	CLIForced *bool `json:"cli_forced"`
	// CLIDownload maps "<goos>-<goarch>" to a binary URL.
	CLIDownload map[string]string `json:"cli_download"`
}

// ReleaseVersion is the published CLI version this manifest describes.
func (m *Manifest) ReleaseVersion() string {
	if v := strings.TrimSpace(m.CLIVersion); v != "" {
		return v
	}
	return strings.TrimSpace(m.Version)
}

// Forced reports whether this update must be installed before the CLI may keep
// working. A non-forced update is applied in the background and takes effect on
// the next launch.
func (m *Manifest) IsForced() bool {
	if m.CLIForced != nil {
		return *m.CLIForced
	}
	return m.Forced
}

// Target is the manifest key for the running platform, e.g. "darwin-arm64".
func Target() string { return runtime.GOOS + "-" + runtime.GOARCH }

// Check returns the published manifest when it is newer than this binary, and
// nil when the CLI is current. Errors are for the caller to swallow: a failed
// check must never stop the user from working.
func Check(ctx context.Context) (*Manifest, error) {
	if app.Version == app.DevVersion {
		return nil, nil
	}
	ctx, cancel := context.WithTimeout(ctx, checkTimeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, app.UpdateManifestURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("更新清单返回 HTTP %d", resp.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}

	var m Manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, err
	}
	if m.ReleaseVersion() == "" {
		return nil, fmt.Errorf("更新清单里没有 cli_version")
	}
	if !IsNewer(m.ReleaseVersion(), app.Version) {
		return nil, nil
	}
	if m.CLIDownload[Target()] == "" {
		// The release exists but ships no binary for this platform — an older
		// manifest format, or a platform we do not build. Nothing to offer, and
		// nagging about it on every launch would help nobody.
		return nil, nil
	}
	return &m, nil
}

// Current reports the running version for display.
func Current() string { return app.Version }

// SelfManaged reports whether this binary was installed by install.sh, i.e. it
// runs out of the versioned install layout. A binary somewhere else (a local
// build, a package manager, a copy on $PATH) is not ours to replace.
func SelfManaged() bool {
	exe, err := os.Executable()
	if err != nil {
		return false
	}
	home, err := app.InstallHomeDir()
	if err != nil {
		return false
	}
	versions := filepath.Join(home, "versions") + string(filepath.Separator)

	candidates := []string{exe}
	// The personas are symlinks, and os.Executable resolves them on some
	// platforms but not others; test both spellings.
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		candidates = append(candidates, resolved)
	}
	for _, path := range candidates {
		if strings.HasPrefix(path, versions) {
			return true
		}
	}
	return false
}

// Apply downloads the manifest's binary into its own version directory and
// re-points every persona symlink at it, the same two steps install.sh takes.
// The running binary stays untouched, so a failure here leaves the previous
// version working.
func Apply(ctx context.Context, m *Manifest, progress dl.ProgressFunc) error {
	url := m.CLIDownload[Target()]
	if url == "" {
		return fmt.Errorf("暂无 %s 的预编译版本", Target())
	}
	target, err := app.InstalledBinaryPath(m.ReleaseVersion())
	if err != nil {
		return err
	}

	// Stage next to the final name so the rename is atomic and a crashed
	// download can never be mistaken for an installed version.
	staged := filepath.Join(filepath.Dir(target), ".mstages.new")
	written, err := dl.File(ctx, url, staged, progress)
	if err != nil {
		return err
	}
	if written < minBinarySize {
		os.Remove(staged)
		return fmt.Errorf("下载到的二进制过小（%d 字节），已丢弃", written)
	}
	if err := os.Chmod(staged, 0o755); err != nil {
		os.Remove(staged)
		return err
	}
	if err := os.Rename(staged, target); err != nil {
		os.Remove(staged)
		return err
	}
	return relink(target)
}

// relink re-points ~/.local/bin/{mstages,mcodex,mclaude} at the new binary.
// A persona that is not a symlink was put there by hand, so it is left alone
// rather than clobbered — install.sh refuses in the same situation.
func relink(target string) error {
	binDir, err := app.InstallBinDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		return err
	}
	// Validate every persona before touching any of them, so a hand-placed
	// file cannot leave the bin directory half pointing at the new version.
	for _, name := range app.PersonaNames {
		link := filepath.Join(binDir, name)
		if info, err := os.Lstat(link); err == nil && info.Mode()&os.ModeSymlink == 0 {
			return fmt.Errorf("%s 已存在且不是软链接，请先手动移除", link)
		}
	}
	for _, name := range app.PersonaNames {
		link := filepath.Join(binDir, name)
		if err := os.Remove(link); err != nil && !os.IsNotExist(err) {
			return err
		}
		if err := os.Symlink(target, link); err != nil {
			return err
		}
	}
	return nil
}

var digitRun = regexp.MustCompile(`\d+`)

// IsNewer compares the numeric parts of two versions, build number included:
// "1.0.2+15" < "1.0.2+16" < "1.0.3". It mirrors isNewerVersion in
// desktop/lib/system/app_updater.dart so both clients agree on what is newer.
func IsNewer(candidate, current string) bool {
	a, b := versionParts(candidate), versionParts(current)
	n := max(len(a), len(b))
	for i := range n {
		x, y := partAt(a, i), partAt(b, i)
		if x != y {
			return x > y
		}
	}
	return false
}

func versionParts(v string) []int {
	matches := digitRun.FindAllString(v, -1)
	parts := make([]int, 0, len(matches))
	for _, m := range matches {
		n, err := strconv.Atoi(m)
		if err != nil {
			// Longer than an int64; treat it as larger than anything sane.
			n = math.MaxInt
		}
		parts = append(parts, n)
	}
	return parts
}

func partAt(parts []int, i int) int {
	if i < len(parts) {
		return parts[i]
	}
	return 0
}
