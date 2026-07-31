//go:build windows

package procs

import (
	"bytes"
	"encoding/csv"
	"os/exec"
	"strconv"
	"strings"
)

// list runs `tasklist /fo csv /nh`, whose columns are
// name,pid,session,session#,memory.
func list() ([]entry, error) {
	cmd := exec.Command("tasklist", "/fo", "csv", "/nh")
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return nil, err
	}

	reader := csv.NewReader(strings.NewReader(out.String()))
	reader.FieldsPerRecord = -1
	rows, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}

	var entries []entry
	for _, row := range rows {
		if len(row) < 2 {
			continue
		}
		pid, err := strconv.Atoi(strings.TrimSpace(row[1]))
		if err != nil {
			continue
		}
		entries = append(entries, entry{pid: pid, comm: strings.TrimSpace(row[0])})
	}
	return entries, nil
}

// executablePath is unknown on Windows: tasklist reports only the image name,
// so callers fall back to matching on the basename alone.
func executablePath(entry) string { return "" }
