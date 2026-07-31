//go:build !windows

package procs

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// list runs `ps -axo pid=,comm=`. The comm column carries no arguments, so a
// home directory containing spaces does not break parsing: everything after
// the pid is the executable name.
func list() ([]entry, error) {
	cmd := exec.Command("ps", "-axo", "pid=,comm=")
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return nil, err
	}

	var entries []entry
	for _, line := range strings.Split(out.String(), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		field, rest, ok := strings.Cut(line, " ")
		if !ok {
			continue
		}
		pid, err := strconv.Atoi(field)
		if err != nil {
			continue
		}
		entries = append(entries, entry{pid: pid, comm: strings.TrimSpace(rest)})
	}
	return entries, nil
}

// executablePath resolves the absolute path of a process's binary. macOS ps
// already reports it in comm; Linux truncates comm to 15 characters, so the
// path is read from /proc. An empty result means "unknown, do not filter on it".
func executablePath(e entry) string {
	if filepath.IsAbs(e.comm) {
		return e.comm
	}
	if target, err := os.Readlink("/proc/" + strconv.Itoa(e.pid) + "/exe"); err == nil {
		return target
	}
	return ""
}
