// Package procs inspects the OS process table. The CLI has no daemon and no
// reference counting, so "is another mstages still running?" and "which pid is
// the shared sing-box?" are answered by scanning processes directly.
package procs

import (
	"os"
	"path/filepath"
	"strings"
)

// personaNames are the basenames the mstages binary can be invoked as.
var personaNames = map[string]bool{
	"mstages": true,
	"mcodex":  true,
	"mclaude": true,
}

// entry is one row of the process table: a pid and the executable name (or
// full path, depending on the platform) with no arguments attached.
type entry struct {
	pid  int
	comm string
}

// OthersRunning reports whether any mstages/mcodex/mclaude process other than
// this one is alive. ignorePIDs lets callers exclude a just-exited child.
//
// When the process table cannot be read it returns true: pretending someone
// else is still running only skips cleanup, while a wrong false would tear down
// the proxy under a live session.
func OthersRunning(ignorePIDs ...int) bool {
	entries, err := list()
	if err != nil {
		return true
	}
	skip := map[int]bool{os.Getpid(): true}
	for _, pid := range ignorePIDs {
		skip[pid] = true
	}
	for _, e := range entries {
		if skip[e.pid] {
			continue
		}
		if personaNames[baseName(e.comm)] {
			return true
		}
	}
	return false
}

// FindByExecutable returns the pids running exactly the given executable. The
// basename is matched first (cheap), then the pid's real executable path is
// resolved and compared, so an unrelated program with the same name is never
// mistaken for ours.
func FindByExecutable(path string) []int {
	entries, err := list()
	if err != nil {
		return nil
	}
	want := baseName(path)
	self := os.Getpid()
	var pids []int
	for _, e := range entries {
		if e.pid == self || baseName(e.comm) != want {
			continue
		}
		if resolved := executablePath(e); resolved != "" && resolved != path {
			continue
		}
		pids = append(pids, e.pid)
	}
	return pids
}

// baseName reduces a path or command name to its lowercase basename without
// any executable extension.
func baseName(comm string) string {
	base := filepath.Base(comm)
	base = strings.TrimSuffix(base, filepath.Ext(base))
	return strings.ToLower(base)
}
