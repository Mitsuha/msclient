package procs

import (
	"os"
	"testing"
)

// TestListFindsSelf exercises the platform-specific process-table parsing: if
// the pid column or the separator were misread, our own pid would be missing.
func TestListFindsSelf(t *testing.T) {
	entries, err := list()
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(entries) == 0 {
		t.Fatal("process table came back empty")
	}
	self := os.Getpid()
	for _, e := range entries {
		if e.pid == self {
			if e.comm == "" {
				t.Error("own entry has an empty command")
			}
			return
		}
	}
	t.Errorf("own pid %d not found among %d entries", self, len(entries))
}

func TestBaseName(t *testing.T) {
	cases := map[string]string{
		// tasklist reports a bare image name; ps reports a path.
		"MSTAGES.EXE":                      "mstages",
		"/usr/local/bin/mcodex":            "mcodex",
		"mclaude":                          "mclaude",
		"/Users/a b/.mstages/bin/sing-box": "sing-box",
	}
	for in, want := range cases {
		if got := baseName(in); got != want {
			t.Errorf("baseName(%q) = %q, want %q", in, got, want)
		}
	}
	if !personaNames[baseName("/opt/homebrew/bin/mcodex")] {
		t.Error("an installed mcodex should be recognized as a persona")
	}
}

// The current test binary is not a persona, so nothing should match it.
func TestOthersRunningIgnoresSelf(t *testing.T) {
	// Only asserts the call completes and does not panic; the machine may
	// legitimately have another mstages running.
	_ = OthersRunning()
}

func TestFindByExecutableNoMatch(t *testing.T) {
	if pids := FindByExecutable("/nonexistent/path/to/sing-box-xyz"); len(pids) != 0 {
		t.Errorf("expected no matches, got %v", pids)
	}
}
