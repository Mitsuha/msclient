package app

import (
	"os"
	"path/filepath"
)

// Version is the released version of this binary, in the Flutter format
// "<major>.<minor>.<patch>+<build>" (see desktop/version.json).
//
// It is injected at build time by packaging/build-cli.sh:
//
//	-ldflags "-X github.com/mirrorstages/mstages/internal/app.Version=1.0.2+15"
//
// A plain `go build` leaves it at DevVersion, which disables the self-updater —
// a local build must never be replaced by a published one.
var Version = DevVersion

// DevVersion marks a binary that was not built by the release pipeline.
const DevVersion = "dev"

// UpdateManifestURL is the release manifest the installer also reads, listing
// the published version and the per-platform CLI download URLs.
const UpdateManifestURL = SingboxDownloadBaseURL + "/latest/version.json"

// InstallCommand is the one-liner that installs or repairs the CLI. It is what
// we point users at when self-updating is not possible.
const InstallCommand = "curl -fsSL " + SingboxDownloadBaseURL + "/latest/install.sh | sh"

// PersonaNames are the command names symlinked to the single binary.
var PersonaNames = []string{"mstages", "mcodex", "mclaude"}

// InstallHomeDir returns the versioned install root, ~/.local/share/mstages.
// The MSTAGES_HOME override matches packaging/install.sh so a custom install
// keeps updating itself in place.
func InstallHomeDir() (string, error) {
	if dir := os.Getenv("MSTAGES_HOME"); dir != "" {
		return dir, nil
	}
	home, err := HomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "share", "mstages"), nil
}

// InstallBinDir returns the directory holding the persona symlinks,
// ~/.local/bin, honoring install.sh's MSTAGES_BIN_DIR override.
func InstallBinDir() (string, error) {
	if dir := os.Getenv("MSTAGES_BIN_DIR"); dir != "" {
		return dir, nil
	}
	home, err := HomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "bin"), nil
}

// InstalledBinaryPath returns where the given version's binary lives:
// <install home>/versions/<version>/mstages.
func InstalledBinaryPath(version string) (string, error) {
	dir, err := InstallHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "versions", version, "mstages"), nil
}
