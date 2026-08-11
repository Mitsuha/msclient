package tools

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFileBackupMoveRoundtrip(t *testing.T) {
	dir := t.TempDir()
	// "auth.json" exists originally; "config.toml" does not.
	writeFile(t, filepath.Join(dir, "auth.json"), "ORIGINAL")

	b := newFileBackup(dir, []string{"auth.json", "config.toml"}, true)
	if err := b.Perform(); err != nil {
		t.Fatalf("Perform: %v", err)
	}

	// Original moved into old_configs; live file gone.
	if _, err := os.Stat(filepath.Join(dir, "auth.json")); !os.IsNotExist(err) {
		t.Errorf("auth.json should have been moved away")
	}
	if got := readFile(t, filepath.Join(dir, backupDirName, "auth.json")); got != "ORIGINAL" {
		t.Errorf("backup content = %q", got)
	}

	// Simulate the CLI writing new config.
	writeFile(t, filepath.Join(dir, "auth.json"), "MSTAGES")
	writeFile(t, filepath.Join(dir, "config.toml"), "MSTAGES_TOML")

	if err := b.Restore(); err != nil {
		t.Fatalf("Restore: %v", err)
	}

	// auth.json restored to original; config.toml (absent originally) removed.
	if got := readFile(t, filepath.Join(dir, "auth.json")); got != "ORIGINAL" {
		t.Errorf("restored auth.json = %q, want ORIGINAL", got)
	}
	if _, err := os.Stat(filepath.Join(dir, "config.toml")); !os.IsNotExist(err) {
		t.Errorf("config.toml should have been removed on restore")
	}
	if _, err := os.Stat(filepath.Join(dir, backupDirName)); !os.IsNotExist(err) {
		t.Errorf("backup dir should be gone after restore")
	}
}

// A move-backup still copies the files marked keepInPlace: the CLI edits
// config.toml in place, so it must survive the backup where the tool expects
// it — and still be restored verbatim afterwards.
func TestFileBackupKeepsMarkedFilesInPlace(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "auth.json"), "ORIGINAL_AUTH")
	writeFile(t, filepath.Join(dir, "config.toml"), "ORIGINAL_TOML")

	b := newFileBackup(dir, []string{"auth.json", "config.toml"}, true).keepInPlace("config.toml")
	if err := b.Perform(); err != nil {
		t.Fatalf("Perform: %v", err)
	}

	if _, err := os.Stat(filepath.Join(dir, "auth.json")); !os.IsNotExist(err) {
		t.Errorf("auth.json should have been moved away")
	}
	if got := readFile(t, filepath.Join(dir, "config.toml")); got != "ORIGINAL_TOML" {
		t.Errorf("live config.toml = %q, want it left in place", got)
	}
	if got := readFile(t, filepath.Join(dir, backupDirName, "config.toml")); got != "ORIGINAL_TOML" {
		t.Errorf("backed up config.toml = %q", got)
	}

	writeFile(t, filepath.Join(dir, "config.toml"), "PRUNED")
	if err := b.Restore(); err != nil {
		t.Fatalf("Restore: %v", err)
	}
	if got := readFile(t, filepath.Join(dir, "config.toml")); got != "ORIGINAL_TOML" {
		t.Errorf("restored config.toml = %q, want ORIGINAL_TOML", got)
	}
}

func TestFileBackupCopySemantics(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "settings.json"), "USER")

	b := newFileBackup(dir, []string{"settings.json"}, false)
	if err := b.Perform(); err != nil {
		t.Fatalf("Perform: %v", err)
	}
	// Copy semantics: original stays in place.
	if got := readFile(t, filepath.Join(dir, "settings.json")); got != "USER" {
		t.Errorf("original should remain, got %q", got)
	}

	writeFile(t, filepath.Join(dir, "settings.json"), "MSTAGES")
	if err := b.Restore(); err != nil {
		t.Fatalf("Restore: %v", err)
	}
	if got := readFile(t, filepath.Join(dir, "settings.json")); got != "USER" {
		t.Errorf("restored = %q, want USER", got)
	}
}

func TestFileBackupRecoversStaleBackupViaManifest(t *testing.T) {
	dir := t.TempDir()
	writeFile(t, filepath.Join(dir, "auth.json"), "ORIGINAL")

	// First run backs up but "crashes" before restore.
	first := newFileBackup(dir, []string{"auth.json"}, true)
	if err := first.Perform(); err != nil {
		t.Fatalf("first Perform: %v", err)
	}
	writeFile(t, filepath.Join(dir, "auth.json"), "MSTAGES")

	// Second run with fresh in-memory state must recover the original first.
	second := newFileBackup(dir, []string{"auth.json"}, true)
	if err := second.Perform(); err != nil {
		t.Fatalf("second Perform: %v", err)
	}
	if got := readFile(t, filepath.Join(dir, backupDirName, "auth.json")); got != "ORIGINAL" {
		t.Errorf("recovered backup = %q, want ORIGINAL", got)
	}
}

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return string(raw)
}
