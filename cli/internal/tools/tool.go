// Package tools implements the mcodex/mclaude personas: initialize a local AI
// CLI tool with MirrorStages credentials and proxy settings, launch it with
// stdio passed through, and restore the user's original config on exit.
package tools

import "context"

// Kind identifies which downstream tool a persona wraps.
type Kind int

const (
	// Codex wraps the `codex` CLI.
	Codex Kind = iota
	// Claude wraps the `claude` CLI.
	Claude
)

// tool abstracts the codex/claude specific configuration behavior.
type tool interface {
	// name is the persona label used in log messages.
	name() string
	// executable is the downstream command to launch (e.g. "codex").
	executable() string
	// performBackup snapshots the user's original config before initialize.
	performBackup() error
	// restoreBackup puts the user's original config back on exit. It is
	// idempotent and safe to call even if performBackup partially ran.
	restoreBackup() error
	// initialize writes MirrorStages credentials and proxy settings, calling
	// the backend as needed with the session token.
	initialize(ctx context.Context, token string) error
}

// newTool constructs the tool implementation for a Kind.
func newTool(kind Kind) tool {
	switch kind {
	case Claude:
		return &claudeTool{}
	default:
		return &codexTool{}
	}
}
