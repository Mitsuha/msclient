package update

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/mirrorstages/mstages/internal/app"
)

// The build number decides upgrades between identical semver releases, so it
// has to participate in the comparison — this mirrors the Dart implementation
// in desktop/lib/system/app_updater.dart.
func TestIsNewer(t *testing.T) {
	cases := []struct {
		candidate, current string
		want               bool
	}{
		{"1.0.2+16", "1.0.2+15", true},
		{"1.0.2+15", "1.0.2+15", false},
		{"1.0.2+15", "1.0.2+16", false},
		{"1.0.3", "1.0.2+99", true},
		{"1.0.2", "1.0.2+1", false}, // a missing build number counts as 0
		{"1.0.2+1", "1.0.2", true},
		{"2.0.0+1", "1.9.9+99", true},
		{"1.0.10+1", "1.0.9+1", true}, // numeric, not lexicographic
		{"1.0.2+15", "dev", true},     // a dev build has no numbers at all
	}
	for _, c := range cases {
		if got := IsNewer(c.candidate, c.current); got != c.want {
			t.Errorf("IsNewer(%q, %q) = %v, want %v", c.candidate, c.current, got, c.want)
		}
	}
}

// The CLI ships on its own cadence, so cli_version/cli_forced win over the
// desktop app's version/forced whenever they are present.
func TestManifestPrefersCLIFields(t *testing.T) {
	var m Manifest
	if err := json.Unmarshal([]byte(`{
		"version":"2.0.0+1","forced":false,
		"cli_version":"1.0.2+16","cli_forced":true
	}`), &m); err != nil {
		t.Fatal(err)
	}
	if got := m.ReleaseVersion(); got != "1.0.2+16" {
		t.Errorf("ReleaseVersion() = %q, want the cli_version", got)
	}
	if !m.IsForced() {
		t.Error("cli_forced should win over forced")
	}
}

// Manifests published before the split only carry the desktop app's pair.
func TestManifestFallsBackToSharedFields(t *testing.T) {
	var m Manifest
	if err := json.Unmarshal([]byte(`{"version":"1.0.2+16","forced":true}`), &m); err != nil {
		t.Fatal(err)
	}
	if got := m.ReleaseVersion(); got != "1.0.2+16" {
		t.Errorf("ReleaseVersion() = %q", got)
	}
	if !m.IsForced() {
		t.Error("an absent cli_forced should fall back to forced, not to false")
	}
}

// cli_forced:false is a real value, not an absent key: it must not fall back to
// a forced desktop release and interrupt the user's run.
func TestManifestUnforcedCLIOnForcedApp(t *testing.T) {
	var m Manifest
	if err := json.Unmarshal([]byte(`{"forced":true,"cli_forced":false}`), &m); err != nil {
		t.Fatal(err)
	}
	if m.IsForced() {
		t.Error("cli_forced:false must not be treated as absent")
	}
}

// A dev build must never replace itself with a published release.
func TestCheckSkipsDevBuilds(t *testing.T) {
	m, err := Check(t.Context())
	if m != nil || err != nil {
		t.Errorf("dev build should skip the check, got (%v, %v)", m, err)
	}
}

func TestTarget(t *testing.T) {
	if Target() == "-" || Target() == "" {
		t.Errorf("Target() = %q", Target())
	}
}

// SelfManaged decides whether we may relink the personas, so it must not
// mistake an arbitrary binary for an installed one.
func TestSelfManagedRejectsForeignPath(t *testing.T) {
	t.Setenv("MSTAGES_HOME", t.TempDir())
	if SelfManaged() {
		t.Error("the test binary is not in the install layout")
	}
}

func TestRelinkPointsEveryPersona(t *testing.T) {
	home := t.TempDir()
	binDir := filepath.Join(t.TempDir(), "bin")
	t.Setenv("MSTAGES_HOME", home)
	t.Setenv("MSTAGES_BIN_DIR", binDir)

	target := filepath.Join(home, "versions", "1.0.0+1", "mstages")
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(target, []byte("binary"), 0o755); err != nil {
		t.Fatal(err)
	}
	// A leftover link from the previous version must be replaced, not skipped.
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(home, "versions", "0.9.0+1", "mstages"),
		filepath.Join(binDir, "mcodex")); err != nil {
		t.Fatal(err)
	}

	if err := relink(target); err != nil {
		t.Fatalf("relink: %v", err)
	}
	for _, name := range app.PersonaNames {
		got, err := os.Readlink(filepath.Join(binDir, name))
		if err != nil {
			t.Errorf("%s: %v", name, err)
			continue
		}
		if got != target {
			t.Errorf("%s -> %s, want %s", name, got, target)
		}
	}
}

// install.sh refuses to clobber a real file in the bin directory; so do we.
func TestRelinkRefusesRealFile(t *testing.T) {
	binDir := t.TempDir()
	t.Setenv("MSTAGES_HOME", t.TempDir())
	t.Setenv("MSTAGES_BIN_DIR", binDir)
	if err := os.WriteFile(filepath.Join(binDir, "mclaude"), []byte("mine"), 0o755); err != nil {
		t.Fatal(err)
	}

	err := relink(filepath.Join(t.TempDir(), "mstages"))
	if err == nil {
		t.Fatal("expected relink to refuse overwriting a real file")
	}
	if _, statErr := os.Stat(filepath.Join(binDir, "mclaude")); statErr != nil {
		t.Errorf("the user's file was removed anyway: %v", statErr)
	}
	// Nothing else should have been linked either: a partially relinked bin
	// directory would mix versions across personas.
	if _, statErr := os.Lstat(filepath.Join(binDir, "mstages")); statErr == nil {
		t.Error("relink linked mstages before refusing")
	}
}
