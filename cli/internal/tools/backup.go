package tools

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// backupDirName is the subdirectory under each tool's config dir that holds the
// user's pre-init files while the CLI runs.
const backupDirName = "old_configs"

const manifestName = ".manifest.json"

// fileBackup snapshots a fixed set of files in a config directory before the
// CLI overwrites them, and restores them when the CLI exits. When move is true
// files are renamed (codex); when false they are copied (claude), preserving
// the original in place until restore.
//
// A manifest records which files existed originally, so a fresh run can recover
// (restore) a backup left behind by a previously crashed run before creating a
// new one.
type fileBackup struct {
	dir     string
	files   []string
	move    bool
	present map[string]bool
}

func newFileBackup(dir string, files []string, move bool) *fileBackup {
	return &fileBackup{dir: dir, files: files, move: move, present: map[string]bool{}}
}

func (b *fileBackup) backupPath() string { return filepath.Join(b.dir, backupDirName) }

// Perform recovers any leftover backup from a crashed run, then snapshots the
// current files.
func (b *fileBackup) Perform() error {
	if _, err := os.Stat(b.backupPath()); err == nil {
		// A prior run did not clean up; restore it before starting over.
		if err := b.Restore(); err != nil {
			return fmt.Errorf("recover stale backup: %w", err)
		}
	}
	if err := os.MkdirAll(b.backupPath(), 0o755); err != nil {
		return err
	}
	for _, name := range b.files {
		src := filepath.Join(b.dir, name)
		if _, err := os.Stat(src); err != nil {
			if os.IsNotExist(err) {
				b.present[name] = false
				continue
			}
			return err
		}
		b.present[name] = true
		dst := filepath.Join(b.backupPath(), name)
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		if b.move {
			if err := os.Rename(src, dst); err != nil {
				return err
			}
		} else {
			if err := copyFile(src, dst); err != nil {
				return err
			}
		}
	}
	return b.writeManifest()
}

// Restore puts the original files back and removes the backup directory. Files
// that were absent originally are deleted (the CLI's writes are undone).
func (b *fileBackup) Restore() error {
	if b.present == nil || len(b.present) == 0 {
		// In-memory state lost (recovery path); fall back to the manifest.
		if err := b.readManifest(); err != nil {
			return err
		}
	}
	var firstErr error
	for _, name := range b.files {
		existed, tracked := b.present[name]
		backup := filepath.Join(b.backupPath(), name)
		live := filepath.Join(b.dir, name)

		if tracked && existed {
			if err := os.MkdirAll(filepath.Dir(live), 0o755); err != nil && firstErr == nil {
				firstErr = err
			}
			// Overwrite the CLI-written file with the original.
			_ = os.Remove(live)
			if b.move {
				if err := os.Rename(backup, live); err != nil && firstErr == nil {
					firstErr = err
				}
			} else {
				if err := copyFile(backup, live); err != nil && firstErr == nil {
					firstErr = err
				}
			}
		} else if tracked && !existed {
			// Did not exist before init: remove what the CLI wrote.
			if err := os.Remove(live); err != nil && !os.IsNotExist(err) && firstErr == nil {
				firstErr = err
			}
		}
	}
	if err := os.RemoveAll(b.backupPath()); err != nil && firstErr == nil {
		firstErr = err
	}
	return firstErr
}

func (b *fileBackup) writeManifest() error {
	raw, err := json.Marshal(b.present)
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(b.backupPath(), manifestName), raw, 0o644)
}

func (b *fileBackup) readManifest() error {
	raw, err := os.ReadFile(filepath.Join(b.backupPath(), manifestName))
	if err != nil {
		return err
	}
	present := map[string]bool{}
	if err := json.Unmarshal(raw, &present); err != nil {
		return err
	}
	b.present = present
	return nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	info, err := in.Stat()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, info.Mode())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}
